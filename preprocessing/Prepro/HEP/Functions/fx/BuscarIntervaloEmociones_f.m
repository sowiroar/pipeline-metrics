function [ a3, a4, b3, b4, eventos_lat] = BuscarIntervaloEmociones_f(EEG)
% Devuelve el intervalo de tiempo en que aparece marca_inicio y marca_fin

eventos_lat(1,1:3)=0;
num_fila = 0;
    for i = 1:length(EEG.event) %for los primeros 30 eventos busca la barca de inicio
       event_i = str2double(EEG.event(i).type);

        %busca marcas de inicio
              if event_i == 201 
                  num_fila=num_fila+1 ; 
                  eventos_lat(num_fila,1)=event_i;
                  eventos_lat(num_fila,2)=(EEG.event(i).latency)/EEG.srate;
                  eventos_lat(num_fila,3)=EEG.event(i).urevent;
                
              elseif event_i == 202                   
                  num_fila=num_fila+1  ;               
                  eventos_lat(num_fila,1)=event_i;
                  eventos_lat(num_fila,2)=(EEG.event(i).latency)/EEG.srate;
                  eventos_lat(num_fila,3)=EEG.event(i).urevent;
                  
              elseif event_i == 203                    
                  num_fila=num_fila+1   ;              
                  eventos_lat(num_fila,1)=event_i;
                  eventos_lat(num_fila,2)=(EEG.event(i).latency)/EEG.srate;
                  eventos_lat(num_fila,3)=EEG.event(i).urevent;
               
              elseif event_i == 204                        
                  num_fila=num_fila+1    ;     
                  eventos_lat(num_fila,1)=event_i;
                  eventos_lat(num_fila,2)=(EEG.event(i).latency)/EEG.srate;
                  eventos_lat(num_fila,3)=EEG.event(i).urevent;
                 
              elseif event_i == 150                  
                  num_fila=num_fila+1;  
                  eventos_lat(num_fila,1)=event_i;
                  eventos_lat(num_fila,2)=(EEG.event(i).latency)/EEG.srate;
                  eventos_lat(num_fila,3)=EEG.event(i).urevent;
                
               else
               end
               

        end
    
         %marca fin siempre debería ser la ultima marca de emociones
     
     eventos_lat(num_fila+1,1)=str2double(EEG.event(end-1).type);
     eventos_lat(num_fila+1,2)=EEG.event(end).latency;
     eventos_lat(num_fila+1,3)=EEG.event(end).urevent;
   

 
    
    %% intervalos bloques emociones 
    if eventos_lat(1,1) == 201 || eventos_lat(1,1) == 202 % si empieza con mot
        % intero
        a3=[eventos_lat(2,2) (EEG.event([eventos_lat(3,3)-1]).latency)/EEG.srate];
        a4=[eventos_lat(6,2) (EEG.event([eventos_lat(7,3)-1]).latency)/EEG.srate];
        % mot
        b3=[eventos_lat(4,2) (EEG.event([eventos_lat(5,3)-1]).latency)/EEG.srate];
        b4=[eventos_lat(8,2) (EEG.event([eventos_lat(9,3)-1]).latency)/EEG.srate]; 

    elseif eventos_lat(1,1) == 203 || eventos_lat(1,1) == 204 % si empieza con intero
        % intero
        b3=[eventos_lat(2,2) (EEG.event([eventos_lat(3,3)-1]).latency)/EEG.srate];
        b4=[eventos_lat(6,2) (EEG.event([eventos_lat(7,3)-1]).latency)/EEG.srate];
        %mot
        a3=[eventos_lat(4,2) (EEG.event([eventos_lat(5,3)-1]).latency)/EEG.srate];
        a4=[eventos_lat(8,2) (EEG.event([eventos_lat(9,3)-1]).latency)/EEG.srate];
    end
  end
   
    

    

     