clear ; clc ;close all;
%% fix_twiddle_generator
N = 24;

fid = fopen("twiddle.txt","w");

for i = 1:N
    fprintf("W_%d_24\n",i-1)
    W = exp(-2*1i*pi*(i-1)/N);
    fix_W = fi(W,1,32,23);
    % real
    fix_W_real_bin = real(fix_W).bin;
    fix_W_real_hex = dec2hex(bin2dec(fix_W_real_bin),8);
    fprintf("real floating point: %.23f\n", real(W));
    fprintf("real fixed point: %.23f\n", real(fix_W));
    fprintf("real fixed point hex: %s\n", fix_W_real_hex);
    fprintf("------------------------------------\n");
    % imag
    fix_W_imag_bin = imag(fix_W).bin;
    fix_W_imag_hex = dec2hex(bin2dec(fix_W_imag_bin),8);
    fprintf("imag floating point: %.23f\n", imag(W));
    fprintf("imag fixed point: %.23f\n", imag(fix_W));
    fprintf("imag fixed point hex: %s\n", fix_W_imag_hex);
    fprintf("------------------------------------\n");
    
    fprintf(fid,"-----------------W_%d_24----------------\n",i-1);
    fprintf(fid,"real: %s\n", fix_W_real_hex);
    fprintf(fid,"imag: %s\n", fix_W_imag_hex);
    fprintf(fid,"-----------------------------------------\n");    
end

fclose(fid);

%%
clear ; clc ;close all;

X = fi(zeros(1,5))
