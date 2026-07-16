function T = compute_frec_table(Frec_metrics, ID)

    T_struct = struct;
    T_struct.ID = ID;

    field = fieldnames(Frec_metrics);

    for i = 1:length(field)
        current_field = field{i};

        current_metric = getfield(Frec_metrics, current_field);

        for j=1:size(current_metric,1)

            T_struct.([current_field '_C_' num2str(j)]) = current_metric(j);
        end

    end
    
    T = struct2table(T_struct);
end