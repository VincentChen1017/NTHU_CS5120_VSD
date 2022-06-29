from configparser import NoSectionError
from copy import deepcopy
from turtle import xcor
import torch.nn as nn
import torch
from typing import Tuple
from typing import List
import numpy as np


def copy_model(model: nn.Module) -> nn.Module:
    result = deepcopy(model)

    # Copy over the extra metadata we've collected which copy.deepcopy doesn't capture
    if hasattr(model, 'input_activations'):
        result.input_activations = deepcopy(model.input_activations)

    for result_layer, original_layer in zip(result.modules(), model.modules()):
        if isinstance(result_layer, nn.Conv2d) or isinstance(result_layer, nn.Linear):
            if hasattr(original_layer.weight, 'scale'):
                result_layer.weight.scale = deepcopy(
                    original_layer.weight.scale)

        if hasattr(original_layer, 'inAct'):
            result_layer.inAct = deepcopy(original_layer.inAct)
        if hasattr(original_layer, 'outAct'):
            result_layer.outAct = deepcopy(original_layer.outAct)
        if hasattr(original_layer, 'output_scale'):
            result_layer.output_scale = deepcopy(original_layer.output_scale)

    return result


def quantized_weights(weights: torch.Tensor) -> Tuple[torch.Tensor, float]:
    '''
    Quantize the weights so that all values are integers between -128 and 127.
    Use the total range when deciding just what factors to scale the float32
    values by.

    Parameters:
    weights (Tensor): The unquantized weights

    Returns:
    (Tensor, float): A tuple with the following elements:
        * The weights in quantized form, where every value is an integer between -128 and 127.
          The "dtype" will still be "float", but the values themselves should all be integers.
        * The scaling factor that your weights were multiplied by.
          This value does not need to be an 8-bit integer.
    '''

    # TODO: Adopt the symmetric quantization by the total range
    tensor_shape = weights.shape
    weights_flt = weights.view(-1)
    weight_max = max(weights_flt)
    weight_min = min(weights_flt)
    # It is fine to directly use torch.max( tensor ) to get the max, but can't use max()
    if weight_max.abs() > weight_min.abs():
        max_abs = weight_max
    else:
        max_abs = weight_min.abs()
    sc_factor = ((2**8)-1)/(2*max_abs)
    weights_flt = (sc_factor*weights_flt).round()
    for index, w in enumerate(weights_flt):
        if w > 127:
            weights_flt[index] = 127
        elif w < -128:
            weights_flt[index] = -128
    # weights_flt = weights_flt.clamp(min=-128, max=127)
    weights = weights_flt.view(tensor_shape)
    return weights, sc_factor


def quantize_layer_weights(model: nn.Module, device):
    for layer in model.modules():
        if isinstance(layer, nn.Conv2d) or isinstance(layer, nn.Linear):
            q_layer_data, scale = quantized_weights(layer.weight.data)
            q_layer_data = q_layer_data.to(device)
            layer.weight.data = q_layer_data
            layer.weight.scale = scale
            if (q_layer_data < -128).any() or (q_layer_data > 127).any():
                print(q_layer_data)
                raise Exception(
                    "Quantized weights of {} layer include values out of bounds for an 8-bit signed integer".format(layer.__class__.__name__))
            if (q_layer_data != q_layer_data.round()).any():
                raise Exception(
                    "Quantized weights of {} layer include non-integer values".format(layer.__class__.__name__))


class NetQuantized(nn.Module):
    def __init__(self, net_with_weights_quantized: nn.Module):
        super(NetQuantized, self).__init__()

        net_init = copy_model(net_with_weights_quantized)

        self.c1 = net_init.c1
        self.s2 = net_init.s2
        self.c3 = net_init.c3
        self.s4 = net_init.s4
        self.c5 = net_init.c5
        self.f6 = net_init.f6
        self.output = net_init.output

        for layer in self.c1, self.c3, self.c5, self.f6, self.output:
            def pre_hook(l, x):
                x = x[0]
                if (x < -128).any() or (x > 127).any():
                    print(x)
                    raise Exception(
                        "Input to {} layer is out of bounds for an 8-bit signed integer".format(l.__class__.__name__))
                if (x != x.round()).any():
                    print(x)
                    raise Exception(
                        "Input to {} layer has non-integer values".format(l.__class__.__name__))
            layer.register_forward_pre_hook(pre_hook)

        # Calculate the scaling factor for the initial input to the CNN
        self.input_activations = net_with_weights_quantized.c1.inAct
        self.input_scale = NetQuantized.quantize_initial_input(
            self.input_activations)

        # Calculate the output scaling factors for all the layers of the CNN
        preceding_layer_scales = []
        for layer in self.c1, self.c3, self.c5, self.f6, self.output:
            layer.output_scale = NetQuantized.quantize_activations(
                layer.outAct, layer[0].weight.scale, self.input_scale, preceding_layer_scales)
            preceding_layer_scales.append(
                (layer[0].weight.scale, layer.output_scale))

    @staticmethod
    def quantize_initial_input(pixels: np.ndarray) -> float:
        '''
        Calculate a scaling factor for the images that are input to the first layer of the CNN.

        Parameters:
        pixels (ndarray): The values of all the pixels which were part of the input image during training

        Returns:
        float: A scaling factor that the input should be multiplied by before being fed into the first layer.
               This value does not need to be an 8-bit integer.
        '''

        # TODO
        IA_max = pixels.max()
        IA_min = pixels.min()
        if IA_max > abs(IA_min):
            max_abs = IA_max
        else:
            max_abs = abs(IA_min)
        sc_factor = ((2**8)-1)/(2*max_abs)

        return sc_factor

    @staticmethod
    def quantize_activations(activations: np.ndarray, n_w: float, n_initial_input: float, ns: List[Tuple[float, float]]) -> float:
        '''
        Calculate a scaling factor to multiply the output of a layer by.

        Parameters:
        activations (ndarray): The values of all the pixels which have been output by this layer during training
        n_w (float): The scale by which the weights of this layer were multiplied as part of the "quantize_weights" function you wrote earlier
        n_initial_input (float): The scale by which the initial input to the neural network was multiplied
        ns ([(float, float)]): A list of tuples, where each tuple represents the "weight scale" and "output scale" (in that order) for every preceding layer

        Returns:
        float: A scaling factor that the layer output should be multiplied by before being fed into the next layer.
               This value does not need to be an 8-bit integer.
        '''
        # TODO
        OA_max = activations.max()
        OA_min = activations.min()

        if OA_max > abs(OA_min):
            max_abs = OA_max
        else:
            max_abs = abs(OA_min)
        n_oa = ((2**8)-1)/(2*max_abs)

        list_len = len(ns)
        n_i = n_initial_input

        if list_len != 0:
            for i in range(list_len):
                for j in range(2):
                    n_i = ns[i][j]*n_i

        sc_factor = n_oa/(n_w*n_i)

        return sc_factor

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        '''
        Please follow these steps whenever processing with input/output scale to scale the input/outputs of each layer:
            * scale = round(scale*(2**16))
            * (scale*features) >> 16
            * Clamp the value between -128 and 127

        To make sure that the intial input and the outputs of each layer are integers between -128 and 127, you may need to use the following functions:
            * torch.Tensor.round
            * torch.clamp
        '''

        # TODO

        x = (self.input_scale*x).floor()
        x = x.clamp(min=-128, max=127)
        x = self.c1(x)

        c1_output_scale = (self.c1.output_scale*(2**16)).round()
        x = ((c1_output_scale*x) >> 16).floor()
        x = x.clamp(min=-128, max=127)
        x = self.s2(x)
        x = self.c3(x)

        c3_output_scale = (self.c3.output_scale*(2**16)).round()
        x = ((c3_output_scale*x) >> 16).floor()
        x = x.clamp(min=-128, max=127)
        x = self.s4(x)
        x = self.c5(x)

        c5_output_scale = (self.c5.output_scale*(2**16)).round()
        x = ((c5_output_scale*x) >> 16).floor()
        x = x.clamp(min=-128, max=127)
        x = torch.flatten(x, 1)
        x = self.f6(x)

        f6_output_scale = (self.f6.output_scale*(2**16)).round()
        x = ((f6_output_scale*x) >> 16).floor()
        x = x.clamp(min=-128, max=127)
        x = self.output(x)

        output_output_scale = (self.output.output_scale*(2**16)).round()
        x = ((output_output_scale*x) >> 16).floor()
        x = x.clamp(min=-128, max=127)

        '''print("c1_output_scale: (befor, after) = ({}, {})".format(
            self.c1.output_scale, c1_output_scale))
        print("c3_output_scale: (befor, after) = ({}, {})".format(
            self.c3.output_scale, c3_output_scale))
        print("c5_output_scale: (befor, after) = ({}, {})".format(
            self.c5.output_scale, c5_output_scale))
        print("f6_output_scale: (befor, after) = ({}, {})".format(
            self.f6.output_scale, f6_output_scale))
        print("output_output_scale: (befor, after) = ({}, {})".format(
            self.output.output_scale, output_output_scale))'''

        return x


class NetQuantizedWithBias(NetQuantized):
    def __init__(self, net_with_weights_quantized: nn.Module):
        super(NetQuantizedWithBias, self).__init__(net_with_weights_quantized)
        preceding_scales = [
            (self.c1[0].weight.scale, self.c1.output_scale),
            (self.c3[0].weight.scale, self.c3.output_scale),
            (self.c5[0].weight.scale, self.c5.output_scale),
            (self.f6[0].weight.scale, self.f6.output_scale),
            (self.output[0].weight.scale, self.output.output_scale)
        ][: -1]

        self.output[0].bias.data = NetQuantizedWithBias.quantized_bias(
            self.output[0].bias.data,
            self.output[0].weight.scale,
            self.input_scale,
            preceding_scales
        )

        if (self.output[0].bias.data < -2147483648).any() or (self.output[0].bias.data > 2147483647).any():
            raise Exception(
                "Bias has values which are out of bounds for an 32-bit signed integer")
        if (self.output[0].bias.data != self.output[0].bias.data.round()).any():
            raise Exception("Bias has non-integer values")

    @ staticmethod
    def quantized_bias(bias: torch.Tensor, n_w: float, n_initial_input: float, ns: List[Tuple[float, float]]) -> torch.Tensor:
        '''
        Quantize the bias so that all values are integers between -2147483648 and 2147483647.

        Parameters:
        bias (Tensor): The floating point values of the bias
        n_w (float): The scale by which the weights of this layer were multiplied
        n_initial_input (float): The scale by which the initial input to the neural network was multiplied
        ns ([(float, float)]): A list of tuples, where each tuple represents the "weight scale" and "output scale" (in that order) for every preceding layer

        Returns:
        Tensor: The bias in quantized form, where every value is an integer between -2147483648 and 2147483647.
                The "dtype" will still be "float", but the values themselves should all be integers.
        '''

        # TODO
        bias_max = bias.max()
        bias_min = bias.min()
        if bias_max > bias_min.abs():
            max_abs = bias_max
        else:
            max_abs = bias_min.abs()

        n_b = ((2**8)-1)/(2*max_abs)

        '''list_len = len(ns)
        n_i = n_initial_input
        for i in range(list_len):
            for j in range(2):
                n_i = ns[i][j]*n_i '''
        bias = (n_b)*bias

        return torch.clamp((bias).round(), min=-2147483648, max=2147483647)
