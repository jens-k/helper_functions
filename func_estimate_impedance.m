function imp = func_estimate_impedance(data, sr)

    f = waitbar(0,'Estimating impedances');

    ImpedanceWindow = 10;
    imp.SR          = sr;
    imp.WINDOW_LEN  = imp.SR*ImpedanceWindow;
    imp.WINDOW_OVL  =  1;  
   
    [b_bp,a_bp] = butter(4,[70 90]*2/imp.SR,'bandpass');
    imp.proc_eeg_f = filter(b_bp,a_bp,data')';

    % power estimation in time domain
    index_max = floor(size(imp.proc_eeg_f,2)/imp.WINDOW_OVL);
    
    imp.Offset = zeros(size(imp.proc_eeg_f,1), index_max);   % time-averaged raw EEG <- OFFSETS
    imp.Impedance = zeros(size(imp.proc_eeg_f,1), index_max);   % power in filtered EEG <- IMPEDANCES
        
    waitbar(0,f);
    for ch=1:size(imp.proc_eeg_f,1)

        for j=1:index_max
            
            fin = j*imp.WINDOW_OVL;
            ini = max( (fin-imp.WINDOW_LEN)+1, 1 );
            
            imp.Offset(ch,j) = mean(data(ch,ini:fin),2);
            imp.Impedance(ch,j) = (sum(imp.proc_eeg_f(ch,ini:fin).^2,2)/((imp.WINDOW_LEN)));

        end
        waitbar(ch/size(imp.proc_eeg_f,1),f);

    end
   close(f)
end

