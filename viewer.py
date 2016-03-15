# coding: utf-8
import matplotlib.pyplot as plt
import matplotlib.mlab as mlab
import numpy as np
import scipy as sp
import sys
import struct
def plot(fnmtx):
    w = len(fnmtx[0])
    h = len(fnmtx)
    k = 1
    for fnarr in fnmtx:
        for fn in fnarr:
            plt.subplot(w,h,k)
            fn(k)
            k += 1
def read_Float32Array_from_file(file_name):
    f32arr = []
    with open(file_name, "rb") as f:
        while True:
            data = f.read(4)
            if not data: break
            f32 = struct.unpack('f', data)
            f32arr.append(f32[0])
        return f32arr

argvs = sys.argv
argc = len(argvs)
if (argc != 2):
    print 'Usage: # python %s filename' % argvs[0]
    quit()

file_name = argvs[1]
sample_rate = 44100
print "open:" + file_name
f32arr = read_Float32Array_from_file(file_name)
print len(f32arr)
def plotPulse(id):
  plt.plot(xrange(len(f32arr)), f32arr)
def plotSpecgram(id):
  nFFT=256
  window=sp.hamming(nFFT)
  Pxx,freqs, bins, im = plt.specgram(f32arr,
                                     NFFT=nFFT, Fs=sample_rate,
                                     noverlap=nFFT-1, window=mlab.window_hanning)
plot([
  [plotPulse, plotSpecgram]
])
plt.show()
