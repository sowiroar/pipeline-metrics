function [Peaks_detected]=peak_detection(signal,srate)
%--------------------- EXPLICACION --------------------------------------:
%Esta funcion esta basada en la funcion peakfinder y necesita que la misma
%este en el path para funcionar. Esta funcion lo que agrega es que le
%pregunta al usuario si el umbral que esta eligiendo esta bien hasta que se
%encuentra el umbral adecuado. Ademas tiene la opcion de que los picos
%esten en tiempos de latencia de acuerdo al sample rate de la señal.
%
%---------------------   INPUTS  -----------------------------------------:
%1_Signal=señal de la cual quiero detectar los picos. La primera dimension
%tiene que valer 1 y la segunda dimension tiene que tener todos los puntos
%de la señal.
%
%2_srate=este input es opcional. Si se indica la funcion calcula el tiempo
%de latencia al que corresponde cada punto de los picos. Si no se indica
%esta informacion no la muestra el toolbox
%
%---------------------   OUTPUTS  -----------------------------------------:
%Peaks_detected.picos=aca se guarda un vector que tiene la ubicacion de los picos
%con el valor de los puntos de muestra
%
%Peaks_detected.picos_tiempo=esta variable, si se ingreso el sample rate, guarda un
%vector que tiene para cada pico 
%
%Peaks_detected.umbral=aca guarda el umbral final que decidio el usuario
%para detectar los picos de la señal
%
%----------------- FUNCIONES QUE LLAMA Y NECESITA --------------------------: 
%peakfinder
%
%
%by hipereolo, 27/01/2015


%% (1) Comienzo con la funcion, guardo la señal como corazon ya que la funcion se creo originalmente para eso
corazon=signal;
clear signal

%% (2) Luego lo que que hago es plotear el corazon para ver cual es el umbral en el
%cual quiero setear el peakfinder
    figure, 
    plot(corazon)

    %Aca empiezo a preguntar cual es el umbral que se elije
    clc; home
    umbral=input('QUE UMBRAL ELEGIS PARA EL PEAKFINDER?= ');
    close

    %Levanto de nuevo el corazon con el peakfinder para ver si esta bien el
    %umbral elegido
    peakfinder(corazon,umbral)
    %x0=0;y0=0;width=1200;height=600;
    %set(gcf,'units','points','position',[x0,y0,width,height]);

    %Le pregunto al usuario si el umbral esta bien o no. Si responde que NO vuelve
    %a arrancar el loop. 
    aceptacion_umbral= input('Esta bien el umbral elegido (escribir SI o NO)?= ','s');
    close

if strcmp(aceptacion_umbral,'NO')
    %Comienza el loop que le permite al usuario probar distintos valores de
    %umbrales hasta que encuentre el que le satisface
    while strcmp(aceptacion_umbral,'NO')
        close
        figure
        plot(corazon)
        clc; home 
        umbral=input('QUE NUEVO UMBRAL ELEGIS PARA EL PEAKFINDER?= ');
        close
        peakfinder(corazon,umbral)
        %x0=0;y0=0;width=1200;height=600;
        %set(gcf,'units','points','position',[x0,y0,width,height]);

        %clc; home 
        aceptacion_umbral= input('Esta bien el umbral elegido (escribir SI o NO)?= ','s');

        if strcmp(aceptacion_umbral,'SI')
            picos=peakfinder(corazon,umbral);           
        else
        end


    end
    close
    clear aceptacion_umbral
    
else
   picos=peakfinder(corazon,umbral);   
    
end
    
%% (3) Aca, si se incluyeron los datos de sample rate, calculo los tiempos de latencia para cada punto
%de los picos que se encontraron

if nargin==1
    picos_times=0; %default hago prueba T
else
    picos_times=picos./srate;
end

Peaks_detected.picos=picos;
Peaks_detected.picos_times=picos_times;
Peaks_detected.umbral=umbral;
clear picos picos_time umbral
clc
home

end
