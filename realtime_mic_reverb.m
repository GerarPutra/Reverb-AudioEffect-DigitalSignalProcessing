function realtime_mic_reverb()
    clear; clc; close all;

    fs = 44100;              
    frameSize = 256;         

    micReader = audioDeviceReader('SampleRate', fs, ...
        'SamplesPerFrame', frameSize, ...
        'NumChannels', 1); 

    speakerWriter = audioDeviceWriter('SampleRate', fs);

    reverb = ReverbSysObj();
    reverb.SampleRate = fs;
    reverb.setup(fs);

    reverb.PreDelay = 0.02;       
    reverb.WetDryMix = 0.5;     
    reverb.DecayFactor = 0.3;    
    reverb.Diffusion = 0.7;
    reverb.HighCutFrequency = 8000;

    scope = timescope( ...
        'SampleRate', fs, ...
        'TimeSpanOverrunAction', 'Scroll', ...
        'TimeSpanSource', 'property', ...
        'TimeSpan', 2, ... 
        'BufferLength', 2 * fs * 3, ... 
        'YLimits', [-1, 1], ...
        'ShowGrid', true, ...
        'ShowLegend', true, ...
        'Title', 'Real-Time Mic Reverb Scope', ...
        'ChannelNames', {'Reverb Left', 'Reverb Right', 'Mic Input'});

    fig = figure('Name', 'Reverb Parameter Tuner', 'Position', [100, 100, 350, 320], ...
        'Color', [0.94, 0.94, 0.94]);

    paramList = {
        'PreDelay', 0.02, 0, 0.2;
        'DecayFactor', 0.3, 0, 1;
        'Diffusion', 0.7, 0, 1;
        'HighCutFreq', 8000, 100, 20000;
        'WetDryMix', 0.5, 0, 1
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
            case 'WetDryMix'
                reverb.pKappa = value;
                reverb.pOneMinusKappa = 1 - value;
        end
    end

    try
        while true
            audioIn = micReader();

            audioOut = reverb.process(audioIn);

            speakerWriter(audioOut);

            scopeData = [audioOut, audioIn]; 
            scope(scopeData);

            drawnow limitrate;
        end

    catch ME
    end

    release(micReader);
    release(speakerWriter);
    release(scope);
end