function [Excitation, Total_Excitation]=bramslow2004_excpatrn(E_Vector, NoChan)
%bramslow2004_excpatrn Calculate excitation pattern and total excitation
%
%   Usage: [Excitation, Total_Excitation] = bramslow2004_excpatrn(E_Vector, NoChan)
%
%   Input parameters:
%     E_Vector      : Excitation per ERB band. Size: (*1* x *NoChan*).
%     NoChan        : Number of output channels (equally distributed on the ERB scale).
%
%   Output parameters:
%     Excitation        : Excitation pattern (in dB SPL). Size: (*1* x *NoChan*).
%     Total_Excitation  : Total excitation (in dB SPL).
%
%   See also: demo_bramslow2004 exp_bramslow2004 bramslow2004
%
%   References: bramslow2004 bramslow2024 bramslow1993

%   #StatusDoc: 
%   #StatusCode: 
%   #Verification: Unknown
%   #Requirements: M-Signal
%   #Author: Lars Bramslow (1993): Original C code
%   #Author: Graham Naylor (1994): Updates to model
%   #Author: Tayyib Arshad (2007): Ported to Matlab
%   #Author: Lars Bramslow (2024): Integration into AMT
%   #Author: Piotr Majdak (2024): Integration for AMT 1.6.0

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.




TotExc = 0.0;

for Chan = 1:1:NoChan

    if E_Vector(Chan) < 0
    end
    TotExc = TotExc + E_Vector(Chan);
    if E_Vector(Chan) > 0
        Excitation(Chan) = 10 * log10(E_Vector(Chan));
    else
        Excitation(Chan) = -100;
    end
end

Total_Excitation = 10 * log10(TotExc);


