function create_nifti(dirDicom)
% Give the original MRI folder of the DICOM file (without going into the /1
% or /2 subfolder) and another folder will be created inside (/nifti/) with
% the nifti representation of the DICOM files in /2/.

% Use as
% create_nifti(dirDicom)
% eg.: create_nifti(pwd)
%
% INPUT VARIABLES:
% dirDicom          String; input folder (one above the /1 or /2 subfolder!!)
%
% AUTHOR:
% Jens Klinzing, jens.klinzing@uni-tuebingen.de

dirIn       = fullfile(dirDicom, '2');
dirOut      = fullfile(dirDicom, 'nifti');

dicm2nii(dirIn, dirOut, 0);

end