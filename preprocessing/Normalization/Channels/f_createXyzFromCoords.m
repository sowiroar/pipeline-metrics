function f_createXyzFromCoords(labels, theta, azimuth, head_circumference, savepath, savename)
%Description:
%Function that creates a .xyz (readable by EEGLab) of the desired BioSemi layout (either 64 or 128)
%INPUTS:
%labels = Cell of Nx1 with the corresponding labels of each channel.
%theta = Cell of Nx1 with the corresponding theta angle (in DEGREES) of each channel.
%azimuth = Cell of Nx1 with the corresponding azimuth angle (in DEGREES) of each channel.
%head_circumference = int of the head circumference of the cap used (in cms).
%savepath = The desired path in which the .xyz will be saved. Current directory by default
%savename = The desired name of the .xyz file to be saved. 'BioSemi64_HeadCircNumcms' by default
%Author: Jhony Mejia

%Defines default filenames and filepaths
if nargin < 5
    savepath = pwd;
end
if nargin < 6
    savename = strcat('BioSemi64_HeadCirc', num2str(head_circumference), 'cms');
end

%If there already exists a'.xyz' file, don't run this script at all
if(exist(fullfile(savepath, strcat(savename, '.xyz')), 'file')) == 2        %2 corresponds to a 'file' output
    disp('WARNING: There already exists a xyz for this Biosemi layout and the given Circumference');
    return
end


%Defines the head radius in mm, given the head_circumference in cms
radius_mm = 10*head_circumference/(2*pi);


%Renames the desired variables
v_theta = deg2rad(theta);
v_azimuth = deg2rad(azimuth);

%Calculates the desired coordinated of x, y and z
x = radius_mm.*sin(v_theta).*cos(v_azimuth);
y = radius_mm.*sin(v_theta).*sin(v_azimuth);
z = radius_mm.*cos(v_theta);

%Writes the coordinated in a table in format .xyz
t = table;
t.Num = (1:length(labels))';
t.X = x;                    %y because in the excel format, 'y' is towards the nose, while in 'xyz' format 'x' is towards the nose
t.Y = y;                   %-x because in the excel format, 'x' is towards the right ear, while in 'xyz' format 'y' is towards the left ear
t.Z = z;                    %z is the same
t.Label = labels;

%Saves the table as a .txt and renames it as a .xyz
savefullpath = fullfile(savepath, savename);
writetable(t, strcat(savefullpath, '.txt'), 'Delimiter', 'tab', 'WriteVariableNames', false);
movefile(strcat(savefullpath, '.txt'), strcat(savefullpath, '.xyz'));

end