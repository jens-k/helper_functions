## Requires mne, mne-qt-browser, numpy
# todo: add/change some fields in the info structure to align them with the data (e.g., filter boundaries)
import numpy as np
import mne

# Setup
# filepath = r"D:\\export ML 128Hz 0.5-45Hz\\npz\\20221114_AS1_0_proc_v1_20221221-1120_lagcorr_fs128_0.5-45Hz.npz"
filepath = r"D:\\export ML 128Hz 0.5-45Hz\\npz\\20221129_ST8_proc_v1_20221221-1848_lagcorr_fs128_0.5-45Hz.npz"


# Load file
print("Loading file " + filepath)
data = np.load(filepath, allow_pickle=True)
print(data.files)

# Create an MNE epochs array    (https://mne.tools/0.16/generated/mne.EpochsArray.html#mne.EpochsArray)
eeg = data['x']
# eeg = np.swapaxes(eeg,1,2)
eeg = np.reshape(eeg, (eeg.shape[0] * eeg.shape[1], eeg.shape[2]))

label_list = list()
for i in data['label']:
    label_list.append(i[0][0])

eeg_info = mne.create_info(label_list, data['fs'][0][0], ch_types= "eeg", verbose=None)      # (https://mne.tools/0.16/generated/mne.create_info.html#mne.create_info)
# eeg = mne.EpochsArray(data = eeg, info = eeg_info, events=None, tmin = 0, verbose=None)
eeg_raw = mne.io.RawArray(eeg.T*(10**-6), eeg_info)

# Visualize
eeg_raw.plot(duration=30, start=0,scalings=dict(eeg=75 * 1e-6), block=True)

# mne.viz.set_browser_backend('qt')  # Enable mne-qt-browser backend if mne < 1.0
# mne.viz.plot_epochs(eeg)
# eeg.plot(block=True)
