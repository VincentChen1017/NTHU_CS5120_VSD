import numba as nb
import numpy as np
import json


def getAllParms():
    weightsDict = {}
    shapeDict = {"c1.conv": [6, 1, 5, 5],
                 "c3.conv": [16, 6, 5, 5],
                 "c5.conv": [120, 16, 5, 5],
                 "f6.fc": [84, 120],
                 "output.fc": [10, 84]}
    ArrList = []
    for key in shapeDict:
        Arr = np.loadtxt('./weights/'+key+".weight.csv",
                         delimiter=',').astype(int)
        shape = shapeDict[key]
        Arr = Arr.reshape(([i for i in shape]))
        ArrList.append(Arr)
        weightsDict[key] = Arr
    weightsDict["outputBias"] = np.loadtxt(
        './weights/'+key+".bias.csv", delimiter=',').reshape(([1, 10])).astype(int)
    scalesDict = {}
    with open('scale_hw.json') as json_file:
        scalesDict = json.load(json_file)

    return weightsDict, scalesDict


@nb.jit()
def MaxPool2d(x, kernel_size=2, stride=2):
    # TODO
    N, C, H, W = x.shape
    x_out = np.zeros((N, C, int(((H-kernel_size)/stride)+1),
                      int((W-kernel_size)/stride + 1)), dtype='int32')

    for n in range(N):
        for c in range(C):
            output_h = 0
            for h in range(0, H, 2):
                output_w = 0
                for w in range(0, W, 2):
                    x_out[n][c][output_h][output_w] = \
                        max(x[n][c][h][w], x[n][c][h][w+1],
                            x[n][c][h+1][w], x[n][c][h+1][w+1])
                    output_w += 1
                output_h += 1
    # np.savetxt('.MaxP.csv', x.reshape(-1), delimiter=',')
    return x_out


@nb.jit()
def ReLU(x):
    # TODO
    x = np.maximum(x, 0)
    '''
    N, C, H, W = x.shape
    for n in range(N):
        for c in range(C):
            for h in range(H):
                for w in range(W):
                    x[n][c][h][w] = x[n][c][h][w] if x[n][c][h][w] > 0 else 0'''
    return x


@nb.jit()
def Linear(psum_range, x, weights, weightsBias=None, psum_record=False):
    # TODO
    psum_record_list = []
    H, W = x.shape  # (1,120)
    C = weights.shape[0]  # (84,120)
    x_out = np.zeros((H, C), dtype='int32')  # (1,84)
    for h in range(H):
        for c in range(C):
            x_out[h][c] = 0
            for w in range(W):
                x_out[h][c] += x[h][w] * weights[c][w]
                if(x_out[h][c] < psum_range[0]):
                    x_out[h][c] = psum_range[0]
                elif(x_out[h][c] > psum_range[1]):
                    x_out[h][c] = psum_range[1]
                if(psum_record is True):
                    psum_record_list.append(x_out[h][c])
            if weightsBias is not None:
                x_out[h][c] += weightsBias[0][c]

    return x_out,  psum_record_list


@nb.jit()
def Conv2d(psum_range, x, weights, out_channels, kernel_size=5, stride=1, bias=False, psum_record=False):
    # TODO
    psum_record_list = []
    N, C, H, W = x.shape
    x_out = np.zeros((N, out_channels, int(((H-kernel_size))+1),
                     int((W-kernel_size) + 1)), dtype='int32')
    R, S = weights.shape[2:4]
    #--------------- For each output activation ---------------#
    for n in range(N):  # Consider the n_th OA groups
        for m in range(out_channels):  # Consider the m_th Output channel, M = output channel
            for p in range((H-kernel_size)+1):  # Consider the OA's height
                for q in range((W-kernel_size) + 1):  # Consider the OA's width
                    x_out[n][m][p][q] = 0
                    #--------------- For convolution ---------------#
                    for r in range(R):
                        for s in range(S):
                            for c in range(C):
                                h = p * stride - 0 + r
                                w = q * stride - 0 + s
                                x_out[n][m][p][q] += x[n][c][h][w] * \
                                    weights[m][c][r][s]
                                if(x_out[n][m][p][q] < psum_range[0]):
                                    x_out[n][m][p][q] = psum_range[0]
                                elif(x_out[n][m][p][q] > psum_range[1]):
                                    x_out[n][m][p][q] = psum_range[1]
                                if(psum_record is True):
                                    psum_record_list.append(x_out[n][m][p][q])

    return x_out,   psum_record_list


def ActQuant(x, scale, shiftbits=16):
    x = np.clip((np.floor(x*scale)).astype('int') >> shiftbits, -128, 127)
    return x
