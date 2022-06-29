import unittest
from nnutils.functional import Conv2d, ReLU, MaxPool2d, Linear, getAllParms, ActQuant
import numpy as np


class OpTestCase(unittest.TestCase):

    def setUp(self):
        bit = 32
        self.number_range = (-(2**(bit-1)), 2**(bit-1) - 1)
        self.weightsDict, self.scalesDict = getAllParms()
        self.max_samples = 100

    def tearDown(self):
        self.weightsDict, self.scalesDict = None, None
        self.source = None

    def test_C1(self):
        for i in range(self.max_samples):
            self.source = "./activations/img{}/".format(i)
            x = np.loadtxt(self.source+"/c1/input.csv",
                           delimiter=',').astype(int)
            x = x.reshape(1, 1, 32, 32)
            x, _ = Conv2d(self.number_range, x,
                          self.weightsDict["c1.conv"], out_channels=6)
            x = ReLU(x).flatten()
            x_ = np.loadtxt(self.source+"/c1/output.csv",
                            delimiter=',').astype(int)
            #np.savetxt("Conv1.csv", x, delimiter=",")
            self.assertTrue(np.all(x == x_))

    def test_S2(self):
        for i in range(self.max_samples):
            self.source = "./activations/img{}/".format(i)
            x = np.loadtxt(self.source+"/s2/input.csv",
                           delimiter=',').astype(int)
            x = x.reshape(1, 6, 28, 28)
            x = MaxPool2d(x).flatten()
            x_ = np.loadtxt(self.source+"/s2/output.csv",
                            delimiter=',').astype(int)
            self.assertTrue(np.all(x == x_))

    def test_C3(self):
        for i in range(self.max_samples):
            self.source = "./activations/img{}/".format(i)
            x = np.loadtxt(self.source+"/c3/input.csv",
                           delimiter=',').astype(int)
            x = x.reshape(1, 6, 14, 14)
            x, _ = Conv2d(self.number_range, x,
                          self.weightsDict["c3.conv"], out_channels=16)
            x = ReLU(x).flatten()
            x_ = np.loadtxt(self.source+"/c3/output.csv",
                            delimiter=',').astype(int)
            #np.savetxt("C3.csv", x, delimiter=",")
            self.assertTrue(np.all(x == x_))

    def test_S4(self):
        for i in range(self.max_samples):
            self.source = "./activations/img{}/".format(i)
            x = np.loadtxt(self.source+"/s4/input.csv",
                           delimiter=',').astype(int)
            x = x.reshape(1, 16, 10, 10)
            x = MaxPool2d(x).flatten()
            x_ = np.loadtxt(self.source+"/s4/output.csv",
                            delimiter=',').astype(int)
            self.assertTrue(np.all(x == x_))

    def test_C5(self):
        for i in range(self.max_samples):
            self.source = "./activations/img{}/".format(i)
            x = np.loadtxt(self.source+"/c5/input.csv",
                           delimiter=',').astype(int)
            x = x.reshape(1, 16, 5, 5)
            x, _ = Conv2d(self.number_range, x,
                          self.weightsDict["c5.conv"], out_channels=120)
            x = ReLU(x).flatten()
            x_ = np.loadtxt(self.source+"/c5/output.csv",
                            delimiter=',').astype(int)
            self.assertTrue(np.all(x == x_))

    def test_F6(self):
        for i in range(self.max_samples):
            self.source = "./activations/img{}/".format(i)
            x = np.loadtxt(self.source+"/f6/input.csv",
                           delimiter=',').astype(int)
            x = x.reshape(1, 120)
            x, _ = Linear(self.number_range, x, self.weightsDict["f6.fc"])
            x = ReLU(x).flatten()
            x_ = np.loadtxt(self.source+"/f6/output.csv", delimiter=',')
            #np.savetxt("F6.csv", x, delimiter=",")
            self.assertTrue(np.all(x == x_))

    def test_OUTPUT(self):
        for i in range(self.max_samples):
            self.source = "./activations/img{}/".format(i)
            x = np.loadtxt(self.source+"/output/input.csv",
                           delimiter=',').astype(int)
            x = x.reshape(1, 84)
            x, _ = Linear(
                self.number_range, x, self.weightsDict["output.fc"], self.weightsDict["outputBias"])
            x = x.flatten()
            x_ = np.loadtxt(self.source+"/output/output.csv", delimiter=',')
            self.assertTrue(np.all(x == x_))

    def test_edges(self):
        for i in range(self.max_samples):
            source = "./activations/img{}/".format(i)
            scalesDict = self.scalesDict

            # input-c1
            x = np.loadtxt(source+"input.csv", delimiter=',')
            x = x.reshape(1, 1, 32, 32)
            x = ActQuant(x, scalesDict['input_scale'], 0)
            x_ = np.loadtxt(source+"/c1/input.csv", delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))

            # c1-s2
            x = np.loadtxt(source+"/c1/output.csv", delimiter=',').astype(int)
            x = ActQuant(x, scalesDict['c1_output_scale'])
            x_ = np.loadtxt(source+"/s2/input.csv", delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))

            # s2-c3
            x = np.loadtxt(source+"/s2/output.csv", delimiter=',').astype(int)
            x_ = np.loadtxt(source+"/c3/input.csv", delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))

            # c3-s4
            x = np.loadtxt(source+"/c3/output.csv", delimiter=',').astype(int)
            x = ActQuant(x, scalesDict['c3_output_scale'])
            x_ = np.loadtxt(source+"/s4/input.csv", delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))

            # s4-c5
            x = np.loadtxt(source+"/s4/output.csv", delimiter=',').astype(int)
            x_ = np.loadtxt(source+"/c5/input.csv", delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))

            # c5-f6
            x = np.loadtxt(source+"/c5/output.csv", delimiter=',').astype(int)
            x = ActQuant(x, scalesDict['c5_output_scale'])
            x = x.reshape(-1, 120)
            x_ = np.loadtxt(source+"/f6/input.csv", delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))

            # f6-output
            x = np.loadtxt(source+"/f6/output.csv", delimiter=',').astype(int)
            x = ActQuant(x, scalesDict['f6_output_scale'])
            x_ = np.loadtxt(source+"/output/input.csv",
                            delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))

            # output
            x = np.loadtxt(source+"/output/output.csv",
                           delimiter=',').astype(int)
            x = ActQuant(x, scalesDict['output_output_scale'])
            x_ = np.loadtxt(source+"output.csv", delimiter=',').astype(int)
            self.assertTrue(np.all(x.flatten() == x_.flatten()))
