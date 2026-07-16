function f_createBiosemiXyz(layout, head_circumference, savepath, savename)
%Description:
%Function that creates a .xyz (readable by EEGLab) of the desired BioSemi layout (either 64 or 128)
%INPUTS:
%layout = '64' or '128'. The desired BioSemi layout.
%head_circumference = int of the head circumference of the cap used (in cms).
%savepath = The desired path in which the .xyz will be saved. Current directory by default
%savename = The desired name of the .xyz file to be saved. 'BioSemi64/128_HeadCircNumcms.xyz' by default
%Author: Jhony Mejia

%Defines default filenames and filepaths
if nargin < 3
    savepath = pwd;
end
if nargin < 4
    savename = strcat('BioSemi', layout, '_HeadCirc', num2str(head_circumference), 'cms');
end

%If there already exists a'.xyz' file, don't run this script at all
if(exist(fullfile(savepath, savename), 'file')) == 2        %2 corresponds to a 'file' output
    disp('WARNING: There already exists a xyz for this Biosemi layout and the given Circumference');
    return
end


%Defines the head radius in mm, given the head_circumference in cms
radius_mm = 10*head_circumference/(2*pi);


%Loads the desired columns needed (theta and azimuth)
if strcmp(layout, '64')
    [numInfo, labelInfo, ~] = xlsread('Cap_coords_all.xls', '64-chan', 'A35:C98');
elseif strcmp(layout, '128')
    [numInfo, labelInfo, ~] = xlsread('Cap_coords_all.xls', '128-chan', 'A35:C162');
else
    disp('ERROR: Please enter a valid Biosemi layout (64 or 128)');
end

%Renames the desired variables
labelInfo = labelInfo(:,1);
for i = 1:length(labelInfo)
    temp = strsplit(labelInfo{i}, ' ');
    labelInfo{i} = temp{1};
end
v_theta = deg2rad(numInfo(:,1));
v_azimuth = deg2rad(numInfo(:,2));

%Calculates the desired coordinated of x, y and z
x = radius_mm.*sin(v_theta).*cos(v_azimuth);
y = radius_mm.*sin(v_theta).*sin(v_azimuth);
z = radius_mm.*cos(v_theta);

%Writes the coordinated in a table in format .xyz
t = table;
t.Num = (1:length(labelInfo))';
t.X = x;                    %y because in the excel format, 'y' is towards the nose, while in 'xyz' format 'x' is towards the nose
t.Y = y;                   %-x because in the excel format, 'x' is towards the right ear, while in 'xyz' format 'y' is towards the left ear
t.Z = z;                    %z is the same
t.Label = labelInfo;

%Saves the table as a .txt and renames it as a .xyz
savefullpath = fullfile(savepath, savename(1:end-4));
writetable(t, strcat(savefullpath, '.txt'), 'Delimiter', 'tab', 'WriteVariableNames', false);
movefile(strcat(savefullpath, '.txt'), strcat(savefullpath, '.xyz'));

end