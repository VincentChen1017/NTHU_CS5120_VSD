clear ; clc ;close all;
%% for generate the input pattern
rng(0,'twister');
a = -50;
b = 50;
f = ((b-a)*rand(1,240) + a) + ((b-a)*1i*rand(1,240) + a*i);
f = fi(f,1,32,23);
in_pattern(f);

%% call the fft function 1 time: can test certain segment(24-point fft) of 10 groups separately to check our golden is correct or not
N = 24;
i = 1; %% i is used to determine which 24-points data want to test
fft8_0 = fix_fft(f(1+24*(i-1):3:N*i));
fft8_1 = fix_fft(f(2+24*(i-1):3:N*i));
fft8_2 = fix_fft(f(3+24*(i-1):3:N*i));
f1 = [fft8_0 , fft8_1 ,fft8_2];
y = fi(zeros(1,N),1,32,23);
y = fft_24(f1);

% for i = 1:N
%     y_real_golden = fi(real(y(i)),1,32,23);
%     y_real_golden_bin = y_real_golden.bin;
%     pointIndex = y_real_golden.WordLength - y_real_golden.FractionLength;
%     y_real_golden_int = y_real_golden_bin(1:pointIndex);
%     y_real_golden_frac = y_real_golden_bin(pointIndex+1:end);
%     y_real_golden_bin = [y_real_golden_int y_real_golden_frac];
%     y_real_golden_hex = dec2hex(bin2dec(y_real_golden_bin),8)
% end
% 
% for i = 1:N
%     y_imag_golden = fi(imag(y(i)),1,32,23);
%     y_imag_golden_bin = y_imag_golden.bin;
%     pointIndex = y_imag_golden.WordLength - y_imag_golden.FractionLength;
%     y_imag_golden_int = y_imag_golden_bin(1:pointIndex);
%     y_imag_golden_frac = y_imag_golden_bin(pointIndex+1:end);
%     y_imag_golden_bin = [y_imag_golden_int y_imag_golden_frac];
%     y_imag_golden_hex = dec2hex(bin2dec(y_imag_golden_bin),8)
% end

%% call the fft function 10 times
N = 24;
X = [];
for i = 1:10
    fft8_0 = fix_fft(f(1+24*(i-1):3:N*i));
    fft8_1 = fix_fft(f(2+24*(i-1):3:N*i));
    fft8_2 = fix_fft(f(3+24*(i-1):3:N*i));
    f1 = [fft8_0 , fft8_1 ,fft8_2];
    y = fi(zeros(1,N),1,32,23);
    y = fft_24(f1);
    X = [X y];
end

%% for get the output golden pattern
out_pattern(X)

%% test mean_square_error, note this is for one 24-points fft
% NN = length(y);
% mean_square_error = 0;
% for i = 1:length(y)
%     if (real(y(i) - y2(i)) ~= 0 || imag(y(i) - y2(i)) ~= 0)
%         fprintf("wrong in %d difference = %.46f%+.46fj \n",i,real(y(i) - y2(i)),imag(y(i) - y2(i)));
%     end
%     error = sqrt(((real(y(i) - y2(i)))^2 + (imag(y(i) - y2(i)))^2));
%     mean_square_error = mean_square_error + error;
% end
% mean_square_error = mean_square_error/NN


%% 8-point fft
function y = fix_fft(f)
    N = length(f);

    if N == 1
        y = f;
    else
        f_even = f(1:2:N);
        even = fix_fft(f_even);
        f_odd = f(2:2:N);
        odd = fix_fft(f_odd);
        fid = fopen('intermediate.txt','a+');
     
        y = fi(zeros(1,N),1,65,46);
        for u = 1:floor(N/2)
            W = fi(exp(-2*1i*pi*(u-1)/N),1,32,23);
            y(u) = even(u) + W*odd(u);
            y(u+N/2) = even(u) - W*odd(u);
            fprintf(fid,"----------------------intermediate W_%d_%d----------------------------\n",(u-1),N); 
            W_real_bin = real(W).bin();
            W_imag_bin = imag(W).bin();
            fprintf(fid,'W_real_%d_%d : %s\n',(u-1),N,dec2hex(bin2dec(W_real_bin),8));
            fprintf(fid,'W_imag_%d_%d : %s\n',(u-1),N,dec2hex(bin2dec(W_imag_bin),8));
        end
   
        fprintf(fid,"----------------------65'bit output-----------------------------------------\n");
        for i = 1:length(y)
            y_real_bin = real(y(i)).bin();
            y_imag_bin = imag(y(i)).bin();
            fprintf(fid,'real: %s%s\n',dec2hex(bin2dec(y_real_bin(33:end))),dec2hex(bin2dec(y_real_bin(1:32))));
            fprintf(fid,'imag: %s%s\n',dec2hex(bin2dec(y_imag_bin(33:end))),dec2hex(bin2dec(y_imag_bin(1:32))));
        end        
        
        y = fi(y,1,32,23);
        
        fprintf(fid,"----------------------intermediate 32'bit output----------------------------\n");
        for i = 1:length(y)
            y_real_bin = real(y(i)).bin();
            y_imag_bin = imag(y(i)).bin();
            fprintf(fid,'%s + %sj\n',dec2hex(bin2dec(y_real_bin),8),dec2hex(bin2dec(y_imag_bin),8));
        end
        fprintf(fid,"----------------------------------------------------------------------\n");
        fclose(fid);
    end
end

%% 8-to-24 point fft
function X = fft_24(f)
    N = length(f);
    
    X = fi(zeros(1,N),1,66,46);
    
    for k = 1:N 
        for l = 1:3
            K = mod(k,8);
            if K == 0
                K = 8;
            end
            W = fi(exp(-2j*pi*(k-1)*(l-1)/N),1,32,23);
            X(k) = X(k) + W*f(K+(l-1)*8);
        end
    end
    X = fi(X,1,32,23);
end

%% input pattern
function in_pattern(f)
    fid_real = fopen('real.txt','w');
    fid_imag = fopen('imag.txt','w');
    N = length(f);
    for i = 1:N
        % for real part
        fix_real_bin = real(f(i)).bin;
        pointIndex = real(f(i)).WordLength - real(f(i)).FractionLength;
        fix_real_int = fix_real_bin(1:pointIndex);
        fix_real_frac = fix_real_bin(pointIndex+1:end);
        fix_real_bin = [fix_real_int fix_real_frac];
        fix_real_hex = dec2hex(bin2dec(fix_real_bin),8);
        fprintf(fid_real,'%s\n',fix_real_hex);
        % for imag part
        fix_imag_bin = imag(f(i)).bin;
        pointIndex = imag(f(i)).WordLength - imag(f(i)).FractionLength;
        fix_imag_int = fix_imag_bin(1:pointIndex);
        fix_imag_frac = fix_imag_bin(pointIndex+1:end);
        fix_imag_bin = [fix_imag_int fix_imag_frac];
        fix_imag_hex = dec2hex(bin2dec(fix_imag_bin),8);
        fprintf(fid_imag,'%s\n',fix_imag_hex);
    end
    fclose(fid_real);
    fclose(fid_imag);

end

%% output pattern
function out_pattern(y)
    N = length(y);
    fid_real_input = fopen('real.txt','r');
    fid_imag_input = fopen('imag.txt','r');
    real_input = textscan(fid_real_input, '%s', 'Delimiter', '\n');
    imag_input = textscan(fid_imag_input, '%s', 'Delimiter', '\n');
    fclose(fid_real_input);
    fclose(fid_imag_input);
    
    fid_real_golden = fopen('real_golden.txt','w');
    fid_imag_golden = fopen('imag_golden.txt','w');
    
    % write the input part of golden
    for i = 1:N
        fprintf(fid_real_golden, '%s\n', real_input{1}{i});
        fprintf(fid_imag_golden, '%s\n', imag_input{1}{i});
    end
    
    % write the output part of golden
    for i = 1:N
        % for real part
        fix_real_golden_bin = real(y(i)).bin;
        pointIndex = real(y(i)).WordLength - real(y(i)).FractionLength;
        fix_real_golden_int = fix_real_golden_bin(1:pointIndex);
        fix_real_golden_frac = fix_real_golden_bin(pointIndex+1:end);
        fix_real_golden_bin = [fix_real_golden_int fix_real_golden_frac];
        fix_real_golden_hex = dec2hex(bin2dec(fix_real_golden_bin),8);
        fprintf(fid_real_golden,'%s\n',fix_real_golden_hex);
        % for imag part
        fix_imag_golden_bin = imag(y(i)).bin;
        pointIndex = imag(y(i)).WordLength - imag(y(i)).FractionLength;
        fix_imag_golden_int = fix_imag_golden_bin(1:pointIndex);
        fix_imag_golden_frac = fix_imag_golden_bin(pointIndex+1:end);
        fix_imag_golden_bin = [fix_imag_golden_int fix_imag_golden_frac];
        fix_imag_golden_hex = dec2hex(bin2dec(fix_imag_golden_bin),8);
        fprintf(fid_imag_golden,'%s\n',fix_imag_golden_hex);
    end
    fclose(fid_real_golden);
    fclose(fid_imag_golden);
   
end















