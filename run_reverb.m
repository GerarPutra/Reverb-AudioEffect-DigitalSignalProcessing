function run_reverb()

    clear; clc; close all;

    frameLength = 1024;
    inputFile = 'oasis-wonderwall-official-video-0-mhqin.wav'; 

    fileReader = dsp.AudioFileReader(inputFile, 'SamplesPerFrame', frameLength, 'PlayCount', 1);
    deviceWriter = audioDeviceWriter('SampleRate', fileReader.SampleRate);

    reverb = ReverbSysObj();
    reverb.SampleRate = fileReader.SampleRate;
    reverb.setup(fileReader.SampleRate);

    scope = timescope( ...
        'SampleRate', fileReader.SampleRate, ...
        'TimeSpanOverrunAction', 'Scroll', ...
        'TimeSpanSource', 'property', ...
        'TimeSpan', 3, ...
        'BufferLength', 3 * fileReader.SampleRate * 2, ...
        'YLimits', [-1, 1], ...
        'ShowGrid', true, ...
        'ShowLegend', true, ...
        'Title', 'Audio with Reverberation vs. Original', ...
        'ChannelNames', {'With Reverb', 'Original'});

    fig = figure('Name', 'Parameter Tuner', 'Position', [100, 100, 350, 320], ...
        'Color', [0.94, 0.94, 0.94]);

    paramList = {
        'PreDelay', 0.05, 0, 0.2;
        'DecayFactor', 0.3, 0, 1;
        'Diffusion', 0.7, 0, 1;
        'HighCutFreq', 8000, 100, 20000;
        'HF Damping', 0.001, 0, 0.01;
        'WetDryMix', 0.4, 0, 1
    };

    yPos = 270;
    for i = 1:size(paramList, 1)
        name = paramList{i, 1};
        defaultVal = paramList{i, 2};
        minVal = paramList{i, 3};
        maxVal = paramList{i, 4};
        
        uicontrol('Style', 'text', 'String', name, ...
            'Position', [10, yPos, 100, 20], 'BackgroundColor', [0.94, 0.94, 0.94]);
        
        hSlider = uicontrol('Style', 'slider', 'Min', minVal, 'Max', maxVal, ...
            'Value', defaultVal, 'Position', [110, yPos+2, 150, 16]);
        
        hEdit = uicontrol('Style', 'edit', 'String', sprintf('%.3f', defaultVal), ...
            'Position', [270, yPos, 60, 20]);
        
        set(hSlider, 'Callback', @(src,~) onSliderChange(src, hEdit, name));
        set(hEdit, 'Callback', @(src,~) onEditChange(src, hSlider, name));
        
        yPos = yPos - 40;
    end

    function onSliderChange(hSlider, hEdit, paramName)
        val = get(hSlider, 'Value');
        set(hEdit, 'String', sprintf('%.4f', val));
        applyParameter(paramName, val);
    end

    function onEditChange(hEdit, hSlider, paramName)
        val = str2double(get(hEdit, 'String'));
        if ~isnan(val)
            set(hSlider, 'Value', val);
            applyParameter(paramName, val);
        end
    end

    function applyParameter(name, value)
        switch name
            case 'PreDelay'
                reverb.PreDelay = value;
            case 'DecayFactor'
                reverb.pDecayGain = 1 - value;
            case 'Diffusion'
                reverb.pBeta = value;
            case 'HighCutFreq'
                reverb.HighCutFrequency = value;
                fs_internal = 29761;
                fc = min(value, fs_internal/2);
                reverb.pLpAlpha = exp(-2*pi*fc/fs_internal);
            case 'HF Damping'
                reverb.pPhi = value;
            case 'WetDryMix'
                reverb.pKappa = value;
                reverb.pOneMinusKappa = 1 - value;
        end
    end
    
    while ~isDone(fileReader)
        audioIn = fileReader();
        audioOut = reverb.process(audioIn);
        deviceWriter(audioOut);
        
        if isa(audioOut, 'int16')
            outDouble = double(audioOut(:,1)) / 32768;
        else
            outDouble = double(audioOut(:,1));
        end
        
        if isa(audioIn, 'int16')
            inDouble = double(audioIn(:,1)) / 32768;
        else
            inDouble = double(audioIn(:,1));
        end
        
        scope([outDouble, inDouble]);
        
        drawnow limitrate; 
    end

    release(fileReader);
    release(deviceWriter);
    release(scope);
end
