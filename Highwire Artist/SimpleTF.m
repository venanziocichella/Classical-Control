classdef SimpleTF
%SIMPLETF  Minimal transfer function for writing controllers with s.
%
%   s = SimpleTF.s;
%   C = 11.8*(1 + 0.2*s + 0.05/s)/(s/100+1);
%   [num, den] = tfdata(C)
%
%   Supports +, -, *, /, ^ (integer powers) between transfer functions and
%   numbers. Core MATLAB only, so no Control System Toolbox is needed.
%   Coefficients are stored in descending powers of s, like tf.

    properties
        num = 1;
        den = 1;
    end

    methods (Static)
        function s = s()
            s = SimpleTF([1 0], 1);
        end
    end

    methods
        function obj = SimpleTF(num, den)
            if nargin > 0
                obj.num = SimpleTF.trim(num);
                obj.den = SimpleTF.trim(den);
            end
        end

        function r = plus(a, b)
            [a, b] = SimpleTF.both(a, b);
            r = SimpleTF(SimpleTF.padd(conv(a.num, b.den), conv(b.num, a.den)), conv(a.den, b.den));
        end

        function r = minus(a, b)
            r = plus(a, -b);
        end

        function r = uminus(a)
            r = SimpleTF(-a.num, a.den);
        end

        function r = uplus(a)
            r = a;
        end

        function r = mtimes(a, b)
            [a, b] = SimpleTF.both(a, b);
            r = SimpleTF(conv(a.num, b.num), conv(a.den, b.den));
        end

        function r = times(a, b)
            r = mtimes(a, b);
        end

        function r = mrdivide(a, b)
            [a, b] = SimpleTF.both(a, b);
            r = SimpleTF(conv(a.num, b.den), conv(a.den, b.num));
        end

        function r = rdivide(a, b)
            r = mrdivide(a, b);
        end

        function r = mpower(a, k)
            if ~isscalar(k) || k ~= round(k)
                error('SimpleTF:power', 'Only integer powers are supported.');
            end
            r = SimpleTF(1, 1);
            for i = 1:abs(k), r = r*a; end
            if k < 0, r = 1/r; end
        end

        function r = power(a, k)
            r = mpower(a, k);
        end

        function [num, den] = tfdata(a, varargin)
            % Normalized so the leading denominator coefficient is 1.
            num = a.num/a.den(1);
            den = a.den/a.den(1);
        end

        function disp(a)
            fprintf('  num: %s\n  den: %s\n', mat2str(a.num, 5), mat2str(a.den, 5));
        end
    end

    methods (Static, Access = private)
        function [a, b] = both(a, b)
            if ~isa(a, 'SimpleTF'), a = SimpleTF(a, 1); end
            if ~isa(b, 'SimpleTF'), b = SimpleTF(b, 1); end
        end

        function c = padd(a, b)
            n = max(numel(a), numel(b));
            c = [zeros(1, n - numel(a)) a] + [zeros(1, n - numel(b)) b];
        end

        function p = trim(p)
            p = double(p(:).');
            k = find(p ~= 0, 1);
            if isempty(k), p = 0; else, p = p(k:end); end
        end
    end
end
