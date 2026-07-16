%Script that creates a .xyz layout (readable by EEGLab), of the desired BioSemi layout and the desired head circumference
layout = '64';                 %Desired BioSemi layout ('64' or '128')
head_circumference = 55;        %Head circumference of the cap used in cms.
f_createBiosemiXyz(layout, head_circumference);