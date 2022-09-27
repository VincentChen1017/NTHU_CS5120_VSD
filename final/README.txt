ESP template generate script:

參照lab0的範例，需要更改的如下：
Enter accelerator name[dummy]: fft
Enter unique accelerator id as three hex digits[04A]: 087
其餘部分由於沒有reg的參數，故在設置ESP環境時，直接按Enter即可。
----------------------------------------------------------

Use pattern:
將pattern資料夾放置在/esp/accelerators/rtl/fft_rtl/sw/baremetal中即可。

2022/09/28 update: hdl file內的rtl code似乎有誤（貌似沒有做round處理），如果要看fft code要去esp內的"fft_rtl_basic_dma64.v"中看。
