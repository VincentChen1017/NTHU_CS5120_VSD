clear ; clc ;close all;
%% for generate the input pattern
rng(0,'twister');
a = -50;
b = 50;
f = ((b-a)*rand(1,240) + a) + ((b-a)*1i*rand(1,240) + a*i);

timer3 = tic;
X_ = fft(f);
fprintf('Execute time for ten 24-points matlab_buildin fft = %f sec\n', toc(timer3));

f = fi(f,1,32,23);

%% call the fft function 1 time: can test certain segment(24-point fft) of 10 groups separately to check our golden is correct or not
N = 24;
i = 1; %% i is used to determine which 24-points data want to test
timer1 = tic;
fft8_0 = fix_fft(f(1+24*(i-1):3:N*i));
fft8_1 = fix_fft(f(2+24*(i-1):3:N*i));
fft8_2 = fix_fft(f(3+24*(i-1):3:N*i));
f1 = [fft8_0 , fft8_1 ,fft8_2];
y = fi(zeros(1,N),1,32,23);
y = fft_24(f1);
fprintf('Execute time for one 24-points fft = %f sec\n', toc(timer1));

%% call the fft function 10 times
N = 24;
X = [];
timer2 = tic;
for i = 1:10
    fft8_0 = fix_fft(f(1+24*(i-1):3:N*i));
    fft8_1 = fix_fft(f(2+24*(i-1):3:N*i));
    fft8_2 = fix_fft(f(3+24*(i-1):3:N*i));
    f1 = [fft8_0 , fft8_1 ,fft8_2];
    y = fi(zeros(1,N),1,32,23);
    y = fft_24(f1);
    X = [X y];
end
fprintf('Execute time for ten 24-points fft = %f sec\n', toc(timer2));

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

     
        y = fi(zeros(1,N),1,65,46);
        for u = 1:floor(N/2)
            W = fi(exp(-2*1i*pi*(u-1)/N),1,32,23);
            y(u) = even(u) + W*odd(u);
            y(u+N/2) = even(u) - W*odd(u);
        end
        y = fi(y,1,32,23);
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

















