clear; clc; close all;

frameLength = 1024;
inputFile = 'y2mate.mp3'; 

fileReader = dsp.AudioFileReader(inputFile, ...
    'SamplesPerFrame', frameLength, 'PlayCount', 1); 
deviceWriter = audioDeviceWriter('SampleRate', fileReader.SampleRate);

reverb = reverberator('SampleRate', fileReader.SampleRate);

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

parameterTuner(reverb);

while ~isDone(fileReader)
    audioIn = fileReader();

    audioOut = reverb(audioIn);

    deviceWriter(audioOut);

    scope([audioOut(:,1), audioIn(:,1)]);

    drawnow limitrate; 
end

release(fileReader);
release(deviceWriter);
release(scope);
