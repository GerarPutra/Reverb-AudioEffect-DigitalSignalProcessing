classdef ReverbSysObj < handle

    properties
        SampleRate = 44100
        PreDelay = 0.05
        HighCutFrequency = 8000
        Diffusion = 0.7
        DecayFactor = 0.3
        HighFrequencyDamping = 0.001
        WetDryMix = 0.4
    end

    properties
    pInternalFs = 29761;
    pPreDelayBuf = [];
    pPreDelayIdx = 1;
    pPreDelayLen = 1;
    pLpAlpha = 0;
    pLpState = 0;
    pApDecBufs = {};
    pApDecIdxs = [];
    pApDecDelays = [142, 107, 379, 277];
    pBeta = 0;
    pTankTopBufs = {};
    pTankTopIdxs = [];
    pTankTopDelays = [4453, 1800, 3720];
    pTankTopLpState = 0;
    pDecayGain = 0;
    pPhi = 0;
    pTankBotBufs = {};
    pTankBotIdxs = [];
    pTankBotDelays = [4217, 2656, 3163];
    pTankBotLpState = 0;
    pKappa = 0;
    pOneMinusKappa = 0;
    pOutputGain = 1.6;
    pIsSetup = false;
end

    methods
        function obj = ReverbSysObj()

        end
      
        function setup(obj, fs)
            if nargin > 1
                obj.SampleRate = fs;
            end
            
            fs_internal = obj.pInternalFs;
            
            obj.pPreDelayLen = max(round(obj.PreDelay * fs_internal), 1);
            obj.pPreDelayBuf = zeros(1, obj.pPreDelayLen);
            obj.pPreDelayIdx = 1;

            fc = min(obj.HighCutFrequency, fs_internal/2);
            obj.pLpAlpha = exp(-2*pi*fc/fs_internal);
            obj.pLpState = 0;

            obj.pBeta = obj.Diffusion;
            obj.pDecayGain = 1 - obj.DecayFactor;
            obj.pPhi = obj.HighFrequencyDamping;
            obj.pKappa = obj.WetDryMix;
            obj.pOneMinusKappa = 1 - obj.WetDryMix;

            obj.pApDecBufs = cell(1, 4);
            obj.pApDecIdxs = ones(1, 4);
            for i = 1:4
                obj.pApDecBufs{i} = zeros(1, obj.pApDecDelays(i));
            end

            obj.pTankTopBufs = cell(1, 3);
            obj.pTankTopIdxs = ones(1, 3);
            for i = 1:3
                obj.pTankTopBufs{i} = zeros(1, obj.pTankTopDelays(i));
            end
            obj.pTankTopLpState = 0;

            obj.pTankBotBufs = cell(1, 3);
            obj.pTankBotIdxs = ones(1, 3);
            for i = 1:3
                obj.pTankBotBufs{i} = zeros(1, obj.pTankBotDelays(i));
            end
            obj.pTankBotLpState = 0;
            
            obj.pIsSetup = true;
        end

                function y = process(obj, x)
            if ~obj.pIsSetup
                obj.setup(obj.SampleRate);
            end

            [numSamples, numChannels] = size(x);
            y = zeros(numSamples, 2);

            for n = 1:numSamples
                if numChannels == 2
                    xMono = 0.5 * (x(n,1) + x(n,2));
                    xDryR = x(n,1); xDryL = x(n,2);
                else
                    xMono = x(n,1);
                    xDryR = x(n,1); xDryL = x(n,1);
                end

                xPreDelayed = obj.pPreDelayBuf(obj.pPreDelayIdx);
                obj.pPreDelayBuf(obj.pPreDelayIdx) = xMono;
                obj.pPreDelayIdx = obj.pPreDelayIdx + 1;
                if obj.pPreDelayIdx > obj.pPreDelayLen, obj.pPreDelayIdx = 1; end

                alpha = obj.pLpAlpha;
                xFiltered = (1 - alpha) * xPreDelayed + alpha * obj.pLpState;
                obj.pLpState = xFiltered;

                signal = xFiltered;
                beta = obj.pBeta;
                for i = 1:4
                    signal = obj.localAllpass(signal, obj.pApDecBufs{i}, ...
                        obj.pApDecIdxs(i), obj.pApDecDelays(i), beta);
                    obj.pApDecIdxs(i) = obj.pApDecIdxs(i) + 1;
                    if obj.pApDecIdxs(i) > obj.pApDecDelays(i), obj.pApDecIdxs(i) = 1; end
                end

                decayGain = obj.pDecayGain;
                phi = obj.pPhi;

                topD1 = obj.pTankTopBufs{1}(obj.pTankTopIdxs(1));
                topD2 = obj.pTankTopBufs{3}(obj.pTankTopIdxs(3)); 
                
                topInput = signal + (topD2 * decayGain); 
                
                obj.pTankTopBufs{1}(obj.pTankTopIdxs(1)) = topInput;
                obj.pTankTopIdxs(1) = obj.pTankTopIdxs(1) + 1;
                if obj.pTankTopIdxs(1) > obj.pTankTopDelays(1), obj.pTankTopIdxs(1) = 1; end

                topLP = (1 - phi) * topD1 + phi * obj.pTankTopLpState;
                obj.pTankTopLpState = topLP;
                topAP = obj.localAllpass(topLP, obj.pTankTopBufs{2}, ...
                    obj.pTankTopIdxs(2), obj.pTankTopDelays(2), beta);
                obj.pTankTopIdxs(2) = obj.pTankTopIdxs(2) + 1;
                if obj.pTankTopIdxs(2) > obj.pTankTopDelays(2), obj.pTankTopIdxs(2) = 1; end

                topD2_new = obj.pTankTopBufs{3}(obj.pTankTopIdxs(3));
                obj.pTankTopBufs{3}(obj.pTankTopIdxs(3)) = topAP;
                obj.pTankTopIdxs(3) = obj.pTankTopIdxs(3) + 1;
                if obj.pTankTopIdxs(3) > obj.pTankTopDelays(3), obj.pTankTopIdxs(3) = 1; end

                botD1 = obj.pTankBotBufs{1}(obj.pTankBotIdxs(1));
                botD2 = obj.pTankBotBufs{3}(obj.pTankBotIdxs(3));
                
                botInput = signal + (botD2 * decayGain);
                
                obj.pTankBotBufs{1}(obj.pTankBotIdxs(1)) = botInput;
                obj.pTankBotIdxs(1) = obj.pTankBotIdxs(1) + 1;
                if obj.pTankBotIdxs(1) > obj.pTankBotDelays(1), obj.pTankBotIdxs(1) = 1; end

                botLP = (1 - phi) * botD1 + phi * obj.pTankBotLpState;
                obj.pTankBotLpState = botLP;
                botAP = obj.localAllpass(botLP, obj.pTankBotBufs{2}, ...
                    obj.pTankBotIdxs(2), obj.pTankBotDelays(2), beta);
                obj.pTankBotIdxs(2) = obj.pTankBotIdxs(2) + 1;
                if obj.pTankBotIdxs(2) > obj.pTankBotDelays(2), obj.pTankBotIdxs(2) = 1; end

                botD2_new = obj.pTankBotBufs{3}(obj.pTankBotIdxs(3));
                obj.pTankBotBufs{3}(obj.pTankBotIdxs(3)) = botAP;
                obj.pTankBotIdxs(3) = obj.pTankBotIdxs(3) + 1;
                if obj.pTankBotIdxs(3) > obj.pTankBotDelays(3), obj.pTankBotIdxs(3) = 1; end

                % --- STAGE 5: Output ---
                % Gunakan output baru dari delay line
                x3R = (topD2_new + botD2_new) / 2 * obj.pOutputGain;
                x3L = x3R;

                kappa = obj.pKappa;
                oneMinusKappa = obj.pOneMinusKappa;
                y(n,1) = oneMinusKappa * xDryR + kappa * x3R;
                y(n,2) = oneMinusKappa * xDryL + kappa * x3L;
            end
                end
                function reset(obj)
                    if obj.pIsSetup
                        obj.setup(obj.SampleRate);
                    end
                end

                function out = localAllpass(~, in, buf, idx, delay, beta)
                    readIdx = idx - delay;
                    while readIdx < 1, readIdx = readIdx + length(buf); end
                    xDelayed = buf(readIdx);
                    yDelayed = buf(idx);
                    out = -beta * in + xDelayed + beta * yDelayed;
                    buf(idx) = out;
                end
    end
end
