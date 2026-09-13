# Spatial Room Impulse Response Extrapolation Using the Image Source Method

Zhenxian Li, Thomas Mckenzie 

# To cite this version:

Zhenxian Li, Thomas Mckenzie. Spatial Room Impulse Response Extrapolation Using the Image Source Method. Proceedings of the 19th Linux Audio Conference, Jun 2025, Lyon, France. ⟨10.5281/zenodo.5720724⟩. ⟨hal-05096059⟩ 

HAL Id: hal-05096059 

https://hal.science/hal-05096059v1 

Submitted on 3 Jun 2025 

HAL is a multi-disciplinary open access archive for the deposit and dissemination of scientific research documents, whether they are published or not. The documents may come from teaching and research institutions in France or abroad, or from public or private research centers. 

L’archive ouverte pluridisciplinaire HAL, est destinée au dépôt et à la diffusion de documents scientifiques de niveau recherche, publiés ou non, émanant des établissements d’enseignement et de recherche français ou étrangers, des laboratoires publics ou privés. 

![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/7b9d7f81d68b4d32f4235adb4a6df66b2f1ac5421ad33d4461bc4ad78f55d703.jpg)


# SPATIAL ROOM IMPULSE RESPONSE EXTRAPOLATION USING THE IMAGE SOURCE METHOD

Zhenxian Li 

INSA Lyon, LVA, UR677 

Villeurbanne, France 

zhenxian.li@insa-lyon.fr 

Thomas McKenzie 

Acoustics and Audio Group 

University of Edinburgh, UK 

thomas.mckenzie@ed.ac.uk 

# ABSTRACT

This paper presents a method for the spatial extrapolation of a single higher-order Ambisonic spatial room impulse response (SRIR) measurement to any desired source−receiver position in the room. An assumption is made that in an augmented / virtual reality scenario, the user will likely be wearing technology that is able to scan and create a model of the room. The method of extrapolation therefore uses the expected geometry and source−receiver positions with the image source method, to estimate the direction, time and amplitude of the direct sound and early reflections. The measured SRIR is then processed to rotate, delay and apply a gain to each image source to extrapolate to the target position. In a numerical comparison, the proposed method is shown to effectively extrapolate direct sound and some early reflections, though the early reflection extrapolation is less accurate and more sensitive to any differences between the real geometry and the one used in the image source model. 

# 1. INTRODUCTION

空间音频用的越来越多了

ir的成分：直，早，晚

Recent advancements in virtual reality (VR) and augmented reality (AR) have underscored the importance of spatial audio in enhancing realism and immersion. Spatial audio is pivotal for creating a compelling virtual environment, provides realistic sound cues that enhance presence [1], and is crucial for applications requiring real-time, low-complexity audio delivery such as video games and virtual meetings. 

A room’s reverberation, which can be measured as a room impulse response (RIR) comprises of direct sound, early reflections, and diffuse reverberation. Among these, the direct sound and early reflections play essential roles in auditory localisation. The direct sound, defined as the acoustic component traveling straight from the sound source to the receiver without significant environmental reflections, carries primary cues regarding source direction, distance, and identity. It is fundamental in creating the initial perception of spatial orientation and auditory presence. Early reflections, arriving shortly after the direct sound through reflections from objects and surfaces such as walls, floor and ceiling. Early reflections are important for speech intelligibility by effectively increasing the signal-to-noise ratio [2], and allow for the inference of the geometry and size of the space [3]. Accurate reproduction of the direct sound and early reflections is thus critical in immersive spatial audio rendering. 

Efficient spatial audio reproduction that aligns with real environments requires concise and computationally efficient rendering [4]. Parameterized rendering addresses this by encoding the acoustic field offline into a model that can be decoded in real-time, allowing for flexible adjustments to various acoustic scenarios. 

Spatial audio reproduction often involves spatial room impulse responses (SRIRs) to capture the acoustic characteristics of an environment, which can then be used to synthesise binaural audio by convolving signals with these SRIRs [5] and rendering the output over headphones. However, this technique requires extensive measurements, and is therefore likely not suitable to wider applications with unknown rooms. 

Recent research on spatial audio reverberation rendering using minimal measurements has been published, such as the Six Degrees of Freedom Parameterised Spatial Audio (6DoF-RIR) by Arend et al. [6], which use a parameterised model based on a single monophonic RIR for efficient real-time synthesis with 6DoF head tracking. Alternatively, Tsunokuni et al. showed it is possible to extrapolate the early part of RIRs in a small room using sparse equivalent sources and image source method [7], though this also used a monophonic RIR. 

其他方法1：参数化模型还有方法2

都没SRIR貌似

Building on these approaches, using an SRIR instead of a monophonic RIR may offer advantages, as the directional information of the direct sound and early reflections is available and can be taken from the measurement. This may lead to improved rendering accuracy and a more immersive experience, as the original spatial data does not need to be inferred or extrapolated from a single-channel source. 

This study presents a method for spatial extrapolation of a single higher-order Ambisonic SRIR within a room to any desired source−receiver position. The image source method is used to calculate the direction, distance and time of arrival of the direct sound and early reflections, with which the SRIR measurement is processed accordingly to a new source−receiver position. 

The paper is organised as follows. Section 2 presents the methodology for SRIR extrapolation, detailing the image source model and the extrapolation processes. Section 3 then presents a numerical evaluation of the method using time-domain, frequency domain and spatial domain analysis. The results of the evaluation are discussed in Section 4, identifying the strengths and weaknesses of the current methodology. Finally, the paper is concluded in Section 5 along with future work. 

# 2. METHOLODOGY

This section describes the methodology of this study, including the image source model to predict information about the direct sound and early reflections and the processing of the SRIR measurement from the original position to a target position. 

# 2.1. SRIR Extraction and Spatial Verification

The initial step involves the extraction of SRIRs from a dataset provided in SOFA (Spatially Oriented Format for Acoustics) format. The dataset is in Ambisonics format is used for its capability to create immersive audio experiences by capturing and reproducing sound in a full-sphere surround setup, utilizing spherical harmonics for detailed audio encoding in three dimensions [8]. This method supports various playback configurations, including multi-speaker setups and binaural decoding for headphones, providing a comprehensive 3D audio experience [9]. 

The positions of sources and receivers are obtained, and their spatial coordinates are explicitly defined. Subsequently, a threedimensional geometric representation of the environment is generated to visually verify the spatial relationship between source and receiver positions, ensuring data integrity and spatial accuracy. 

![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/9ab43f951bc48cfc06053a017e8da59acd79e3541fdf4e0645f454d29bea6a7e.jpg)



Figure 1: Illustration of the source (S) and receiver (R) positions used in the evaluation. Microphones and loudspeakers are oriented facing north and south, respectively, according to the illustration orientation. Original S−R pair (to be extrapolated) shown by blue arrow; target S−R pair shown by red arrow.


# 2.2. Diffuse Field Assumption and Subspace Decomposition

In this implementation, SRIR extrapolation is performed by separately processing the direct sound and early reflections, while assuming the diffuse late reverberation to be spatially invariant within a room—at least from a perceptual standpoint. To aid in this, the SRIR measurement is processed using direct and residual subspace decomposition1, following the approach by Deppisch et al. [10]. A generalised singular value decomposition (GSVD) is performed to effectively isolate the direct sound and salient early reflections from the diffuse reverberation, which is treated as the residual. This decomposition leverages the fact that direct sound and early reflections occupy a limited subspace within the full signal space captured by the microphone array, thus enabling their extraction through low-rank approximations. 

Let $h _ { \mathrm { o r i g } } ( t )$ denote the measured higher-order Ambisonic SRIR at the original position. It is first decomposed into a salient component (comprising direct sound and early reflections) and a diffuse component (late reverberation): 

$$
h _ {\text {o r i g}} (t) \xrightarrow {\text {G S V D}} \left\{ \begin{array}{l l} h _ {\text {s a l}} (t), & (\text {d i r e c t} + \text {e a r l y r e f l e c t i o n s}) \\ h _ {\text {d i f f}} (t), & (\text {d i f f u s e r e v e r b e r a t i o n}) \end{array} \right. \tag {1}
$$

Only $h _ { \mathrm { s a l } } ( t )$ will be manipulated in the spatial extrapolation process; $h _ { \mathrm { d i f f } } ( t )$ is kept unchanged under the assumption that late reverberation is approximately position-invariant within the same room [11]. This assumption would not apply in rooms with more complex geometry, however, such as L shaped rooms [12] or between coupled rooms [13]. While the separation of salient and diffuse parts of the SRIR is not an entirely necessary step in the extrapolation method, it means that when processing arrivals, the residual is untouched and theoretically, only the part of the SRIR in the direction of interest is processed. 

# 2.3. Image-Source Model for Arrival Time and Direction

The Image-Source Model (ISM) is used to simulate the direct sound and early reflections for a known room’s geometry. This is done for both the original and target source and receiver positions. The ISM is used to calculate the coordinates, propagation delays, distances, and arrival directions for the direct sound and early reflections at both original and target positions. [14] 

![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/f0ae042a2ce7a40df2da5c3a28e7fa7de5b1dfb3b2dc36c2da01282baed18450.jpg)



(a) Original


![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/99ed3c18a867a13b40404f314a0d88985e02373af087aca1f2d4a1c12edb913c.jpg)



(b) Target



Figure 2: Two-dimensional plot of the calculated 2nd order image sources (black stars) with source (green triangle) and receiver (orange circle).


To use the ISM derived data in the extrapolation, it is essential that the measured data and theoretical predictions are aligned in terms of spatial direction and arrival timing [14]. In practice, the measured SRIR might have been truncated to begin exactly at the theoretical zero time, necessitating temporal alignment adjustments (counter-delay), and it may be that the coordinate systems between the measurement and the ISM are not the same. Therefore, a series of alignment checks are performed at this stage of the method. 

Given the known room geometry, virtual images of the sound source are created by mirroring it across each boundary (e.g., walls, floor, ceiling) according to the reflection order of interest. Let $\mathbf { x } _ { S } ^ { ( n ) }$ denote the position of the $_ n$ -th image source, and ${ \bf x } _ { R } ^ { \left( \mathrm { o r i g } \right) }$ xR , $\mathbf { x } _ { R } ^ { ( \mathrm { t a r } ) }$ x x(tar) be the coordinates of the original and target receiver positions, respectively. 

Time-of-Arrival For each image source $_ n$ , the corresponding propagation distances and hence time-of-arrival (ToA) are obtained. Specifically, 

$$
\tau_ {n} ^ {\left(\text {o r i g}\right)} = \frac {\left\| \mathbf {x} _ {R} ^ {\left(\text {o r i g}\right)} - \mathbf {x} _ {S} ^ {(n)} \right\|}{c}, \quad \tau_ {n} ^ {\left(\text {t a r}\right)} = \frac {\left\| \mathbf {x} _ {R} ^ {\left(\text {t a r}\right)} - \mathbf {x} _ {S} ^ {(n)} \right\|}{c}, \tag {2}
$$

where $c$ is the speed of sound in air, set in this study as $3 4 3 ~ \mathrm { m / s }$ . These form the direct and early-reflection arrival times at the 

original and target positions, respectively. 

Arrival Directions Once the positions of each image source have been determined, the direction-of-arrival (DoA) for each reflection can be computed via 

$$
\boldsymbol {\Omega} _ {n} ^ {(\text {o r i g})} = \operatorname {d i r} \left(\mathbf {x} _ {R} ^ {(\text {o r i g})}, \mathbf {x} _ {S} ^ {(n)}\right), \quad \boldsymbol {\Omega} _ {n} ^ {(\text {t a r})} = \operatorname {d i r} \left(\mathbf {x} _ {R} ^ {(\text {t a r})}, \mathbf {x} _ {S} ^ {(n)}\right), \tag {3}
$$

where $\mathrm { d i r } ( \cdot )$ maps the coordinates of the receiver and the (image) source to spherical angles $( \varphi , \theta )$ (azimuth and elevation), and so equation (3) can be rewritten as 

$$
\boldsymbol {\Omega} _ {n} ^ {(\text {o r i g})} = \left(\phi_ {n} ^ {(\text {o r i g})}, \theta_ {n} ^ {(\text {o r i g})}\right), \quad \boldsymbol {\Omega} _ {n} ^ {(\text {t a r})} = \left(\phi_ {n} ^ {(\text {t a r})}, \theta_ {n} ^ {(\text {t a r})}\right). \tag {4}
$$

Propagation Distances and Sorting Similarly, the propagation distances for reflection $n$ at each position are 

$$
r _ {n} ^ {\mathrm {(o r i g)}} = \left\| \mathbf {x} _ {R} ^ {\mathrm {(o r i g)}} - \mathbf {x} _ {S} ^ {(n)} \right\|, \quad r _ {n} ^ {\mathrm {(t a r)}} = \left\| \mathbf {x} _ {R} ^ {\mathrm {(t a r)}} - \mathbf {x} _ {S} ^ {(n)} \right\|. (5)
$$

The image sources are sorted based on the mean of $r _ { n } ^ { \mathrm { ( o r i g ) } }$ and $r _ { n } ^ { ( \mathrm { t a r } ) }$ rn (or equivalently $\tau _ { n } ^ { \mathrm { ( o r i g ) } }$ and $\tau _ { n } ^ { \mathrm { ( t a r ) } } .$ ), prioritising arrivals that are shorter in distance (and thus earlier in time). The rationale for sorting in this way is so that the most perceptually relevant arrivals are processed first, as arrivals from the SRIR measurement are removed to be processed (see Section 2.4). 

# 2.4. SRIR Extrapolation Using Arrival Manipulation

Each identified arrival — comprising either the direct sound or an early reflection — is individually processed through a sequence of operations. From $h _ { \mathrm { s a l } } ( t )$ , each significant early arrival $n$ is isolated by windowing around $\tau _ { n } ^ { \mathrm { ( o r i g ) } }$ : 

$$
k _ {n} (t) = w \left(t - \tau_ {n} ^ {\text {(o r i g)}}\right) \cdot h _ {\text {s a l}} (t), \tag {6}
$$

where $w ( \cdot )$ is a short temporal window (set in this study as 4 ms for the direct sound and 1 ms for an early reflection) around each arrival that is applied to isolate it from the original SRIR at the calculated arrival time of the original position. The isolated arrival is then removed, leaving the rest of the salient SRIR. The temporal window is characterized by linear ramps with ascending and descending phases of 5 and 10 samples, respectively. 

The residual SRIR, denoted as $h _ { \mathrm { r e s } } ( t )$ , is obtained by removing all isolated early arrivals $k _ { n } ( t )$ from the original salient SRIR $h _ { \mathrm { { s a l } } } ( t )$ : 

$$
h _ {\text {r e s}} (t) = h _ {\text {s a l}} (t) - \sum_ {n = 1} ^ {N _ {\text {e a r l y}}} k _ {n} (t). \tag {7}
$$

This operation effectively eliminates the contributions of all early arrivals calculated by Image source model, yielding a signal that contains the remaining components of the $h _ { \mathrm { { s a l } } } ( t )$ . 

For each extracted arrival $r _ { n } ( t )$ , three adjustments are computed to map from the original to the target positions: 

1. Time shift: 

$$
\Delta \tau_ {n} = \tau_ {n} ^ {(\mathrm {t a r})} - \tau_ {n} ^ {(\mathrm {o r i g})}. \tag {8}
$$

2. Amplitude scaling (assuming free-field distance law): 

$$
g _ {n} = \frac {r _ {n} ^ {\left(\text {o r i g}\right)}}{r _ {n} ^ {\left(\operatorname {t a r}\right)}}. \tag {9}
$$

3. HOA-domain rotation to align directions: To rotate the $_ n$ -th reflection from its original direction to match the target direction in the HOA domain, the angle offsets are computed as 

$$
\Delta \phi_ {n} = \phi_ {n} ^ {(\mathrm {t a r})} - \phi_ {n} ^ {(\mathrm {o r i g})}, \quad \Delta \theta_ {n} = \theta_ {n} ^ {(\mathrm {t a r})} - \theta_ {n} ^ {(\mathrm {o r i g})}. \tag {10}
$$

$$
\mathbf {k} _ {n} ^ {\prime} (t) = R \left(\Delta \phi_ {n}, \Delta \theta_ {n}\right) \mathbf {k} _ {n} (t), \tag {11}
$$

where $\mathbf { k } _ { n } ( t )$ is the vector of HOA channels for the $n$ -th arrival, and $R$ is the HOA rotation matrix for Ambisonic order $N$ ) [8]. 

Combining these, the transformed excerpt $k _ { n } ^ { \prime } ( t )$ is inserted back into the SRIR timeline at $\tau _ { n } ^ { \mathrm { ( t a r ) } }$ : 

$$
k _ {n} ^ {\prime} (t) = g _ {n} \left[ R \left(\Delta \phi_ {n}, \Delta \theta_ {n}\right) \mathbf {k} _ {n} (t) \right] _ {t \mapsto t + \Delta \tau_ {n}}. \tag {12}
$$

After processing all major early arrivals $n = 1 , \ldots , N _ { \mathrm { e a r l y } }$ , they are summed into a single HOA signal to form the new salient component at the target position: 

$$
h _ {\text {s a l}} ^ {(\operatorname {t a r})} (t) = h _ {\text {r e s}} (t) + \sum_ {n = 1} ^ {N _ {\text {e a r l y}}} k _ {n} ^ {\prime} (t). \tag {13}
$$

Finally, as the diffuse portion remains unchanged: 

$$
h _ {\text {e x t r a p}} (t) = h _ {\text {s a l}} ^ {(\operatorname {t a r})} (t) + h _ {\text {d i f f}} (t). \tag {14}
$$

Thus, $h _ { \mathrm { e x t r a p } } ( t )$ serves as the spatially extrapolated SRIR for the target source–receiver configuration. 

# 3. EVALUATION

To evaluate the proposed method, a dataset of SRIR measurements was used from the Arni variable acoustics room at Aalto University’s Acoustics Lab, encompassing three source positions and seven receiver positions, detailed in Fig. 1. These positions, carefully chosen to mimic realistic performance scenarios, involve a linear array of receivers spaced 1.25 meters apart, with some near the room’s perimeter, and sources directed towards a common “front.” the variable acoustics 6DoF dataset2 (as described in [15]). The measurements used in this study to evaluate the SRRI extrapolation method were those with medium reverberance, with octave-band [500 Hz, 1 kHz, 2 kHz] RT60 values of [0.50, 0.54, 0.68] s, recorded at a background noise level of 20.5 dB SPL(A). This dataset was recorded at 24-bits with a $4 8 \mathrm { k H z }$ sampling rate. 

The proposed method is evaluated by taking an SRIR measured at one position in the room (herein referred to as the original position) and applying the extrapolation process to transform it to another position in the room (herein referred to as the target position). The original and extrapolated SRIR are then compared to a ground truth SRIR measurement made at the target position. 

The pair of room acoustics measurements used in the evaluation correspond to the source − receiver (S−R) positions as follows (and illustrated in Fig. 1): 

• Original: S2−R4 (blue) 

• Target: S3−R2 (red) 

These were chosen as a number of factors change from the original to target position: the distance between the source and receiver increases, and also the direction of the source changes. 

# 3.1. Time-domain

To evaluate the amplitude and temporal nature of the extrapolation method, Fig. 3 presents a time-domain comparison of the first 50 ms of the original, extrapolated and target SRIRs (omnidirectional channel). The main point of observation here is that the direct sound is clearly well extrapolated in both time and level. Secondly, the first (and most major) early reflection has moved in time from the original position, which matches the target position, however it has not necessarily moved to the correct place or level. This is likely due to a mismatch between the ISM 

![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/1e04785611cb94872316f7e24f3e86dcf80f5574b04a4b4d4409cd6b82441e8b.jpg)



(a) Original


![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/f3fede3cc3e5831d93531898b9645b59b8e23b0be27bf3d0cee36963e579ebb0.jpg)



(b) Extrapolated



Figure 3: Time-domain comparison overlaying the target SRIR on the original (top) and extrapolated (bottom) SRIRs, omnidirectional channel. The original and target source−receiver pairs are S2−R4 and S3−R2, respectively (as labelled in Fig. 1).


and the real room measurements. Some of the other reflections have been moved too, and inaccuracies clearly exist in these too. 

To get an understanding of the effect of extrapolation on loudness, the root-mean-square (RMS) amplitude of the omnidirectional channel of the SRIRs was calculated. This was done for the entire duration of the SRIR. The RMS amplitude of the original, extrapolated and target SRIRs is -40.5dB, -44.8dB and -45.0dB, respectively. This shows that the method extrapolates the amplitude effectively. 

# 3.2. Frequency-domain

To assess the effect of extrapolation on the frequency response of the SRIRs, the original, extrapolated and target SRIRs were first rendered binaurally. This was done using dual-band Ambisonic decoding (mode-matching below $1 . 8 \mathrm { k H z }$ , max-r above), with time-alignment above $1 . 8 \mathrm { k H z }$ [16] and Ambisonic diffuse-field equalisation [17] pre-processing3, and non-individualised Neumann KU100 HRTFs [18]. 

Fig. 4 presents the frequency responses of the left and right binaurally rendered SRIRs, overlaying the extrapolated response on the original and target responses. Firstly, it is again evident how the extrapolation method matches the level well. Additionally, it is clear that the frequency response above $1 \ \mathrm { k H z }$ is very well matched for the extrapolated and target responses, for both left and right, with differences largely falling within 1 dB between $1 \ \mathrm { k H z }$ and $1 0 ~ \mathrm { k H z }$ . This is a significant change from the original response. The binaural levels are well extrapolated when considering the direction of the source has moved from front-right to front-left. Below 1 kHz however, inaccuracies are evident in the extrapolated response. This could be due to mismatch between the geometry used in the ISM and the real geometry of the measured room, or could be due to the simplifications inherent in the ISM: namely the geometric reflection modeling which neglects wave effects such as mode buildup, resonance and diffraction. 

To predict how similar the extrapolated SRIRs will be perceived in timbre, the PBC-2 auditory model [19] was used to predict the colouration between the binaural signals. The PBC-

![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/421a07f3ca0a0c1e4c07b31e7d77ceefdd3f8200d019c6b172d1c6dafcd01d0a.jpg)



(a) Original


![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/d1393fbf66405bf3b08f0d041281ab6a89702e33bbf80421a892e781d1526da1.jpg)



(b) Extrapolated



Figure 4: Frequency-domain comparison overlaying the target SRIR on the original (top) and extrapolated (bottom) SRIRs, which have been rendered binaurally. The original and target source−receiver pairs are S2−R4 and S3−R2, respectively (as labelled in Fig. 1).


![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/73b2fdbf45f995bf39bd80910a6dacaed85b86b657ed423329cb1dc56eb0c39c.jpg)



Figure 5: Estimated direction-of-arrival of direct sound and early reflections for the original, extrapolated and target SRIRs. The original and target source−receiver pairs are S2−R4 and S3−R2, respectively (as labelled in Fig. 1).


2 model combines signal rectification, high frequency smoothing, equivalent rectangular bandwidth frequency weighting, and signal-dependent weighting of the left and right colouration values to produce a single binaural colouration prediction. The version used in this study is available in the Auditory Modeling Toolbox under the model name mckenzie2025. PBC-2 calculations were made with 1/3 octave smoothing applied at all frequencies. The PBC-2 value between the binauralised original and target SRIRs was 91.4, and the PBC-2 between the binauralised extrapolated and target SRIRs was 37.4 (where 100 is highly coloured and 0 is no colouration). This shows that colouration is significantly reduced by the extrapolation method. However, the difference between the extrapolated and target SRIRs is still quite high, and it’s highly likely this would be audible. 

# 3.3. Direction Of Arrival

To evaluate the effect of extrapolation on the directionality of the direct sound and early reflections, the direction-of-arrival (DoA) was estimated above $3 \mathrm { k H z }$ in two degree resolution for the original, extrapolated and target SRIRs. This was done by steering a 4th-order hyper-cardioid beamformer (sometimes referred to as normalised plane wave decomposition) in all directions on the sphere [20] and calculating the power, which can be used to deduce directional information and the relative level of the direct sound and loudest early reflections. 

![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/0a6fbc6843cdac792a57b6884c72cf7e87b6c02d36471913b3622037a99ada0a.jpg)



(a) Original


![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/005fdff7ccb6d456b4b0e4b284278c9007dc3782347335d5c5123b17d13fe6cf.jpg)



(b) Extrapolated


![image](https://cdn-mineru.openxlab.org.cn/result/2026-05-04/4e3f7b7b-8712-4fe2-8e28-180bbae8b1f2/3df28549e86afdccb2facaecc9b9be63e293ad70f747b13c30fdd281f667eb7a.jpg)



(c) Target



Figure 6: Normalised power response of the original, extrapolated and target SRIRs showing the seven highest arrivals. The original and target source−receiver pairs are S2−R4 and S3−R2, respectively (as labelled in Fig. 1).


Firstly, the seven locations with the highest power were extracted, which likely estimate the horizontal DoA of the direct sound and first order early reflections. This is presented in Fig. 5. Both the DoA and power of most arrivals appears to be extrapolated fairly effectively, although some (e.g. around $1 8 0 ^ { \circ }$ and $- 1 3 5 ^ { \circ }$ in the target) are poorly matched by the extrapolation. 

Secondly, to get a three-dimensional view of the spatial qualities of the extrapolation, Fig. 6 presents the normalised power responses in the same $2 ^ { \circ }$ resolution over the sphere. The DoA of the direct sound appears well steered, as was observed in Fig. 5, however in this plot the other arrivals are harder to see, and it appears that some directions are less clear. Again, the arrival around $1 8 0 ^ { \circ }$ in the target seems to have been poorly steered by the extrapolation method. The reason for this is likely a mismatch between the ISM and measurements, which has meant that the arrival was extracted at the wrong time. 

# 4. DISCUSSION

The results show that the proposed method for spatial extrapolation of a single SRIR measurement using ISM is reasonably effective as a simple method. The ISM is able to predict the direction, time and amplitude of the direct sound and early reflections for both the original and target source−receiver positions, which are used to augment an SRIR measured at the original source−receiver position. Comparing the original SRIR 

and extrapolated version of the original SRIR to the target SRIR, the RMS amplitude is significantly improved, and the predicted colouration is significantly reduced. 

The direct sound appears to be the most accurately extrapolated, in all three measures of direction, time and amplitude. The first early reflections are somewhat accurately extrapolated, though the inaccuracies increase as time goes on. 

A likely cause of much of the errors in the method is where the image source and the measurement are mismatched. A number of options exist for what causes this mismatch. The simplest of these is that the geometry, source positions and receiver positions were not accurately measured. Mismatch in these would mean that the image sources are in the wrong positions, leading to errors that compound as the order of reflection increases. Similarly, the image source method used here assumes that walls are perfectly flat and perfectly reflective. In reality, both the geometry and materials making up the room are more complex: there are objects in the room and the walls have texture. Finally, the current method does not account for source directivity. This will likely affect the high frequency timbre the most. Whilst the high frequencies were shown to be relatively well extrapolated in the example in this study, the inaccuracies would likely be more noticeable in cases where one of the receiver positions is behind or strongly to the side of the source position. 

Future work will look at how the ISM can be matched closer to the real room. It may be possible to alter the geometry and source−receiver positions through a comparison of the ISM simulation and the measurement at the original source−receiver position. 

Finally, for each arrival, the proposed method extracts the entire signal at the desired time window. The arrivals instead could be extracted using a beamforming approach, in order to only extract in the direction of the original arrival. This would likely improve results where two arrivals occur at a similar time. 

Though results are only presented here for a single extrapolation, multiple source receiver positions were tried and it worked similarly well for all. Future evaluation will report results for all as well as look at different datasets, and also how the method works perceptually using listening tests. The present study is limited to static source–listener pairs; however, in AR/VR scenarios continuous motion could cause the current distance-based resorting to swap image-source indices and thus generate audible artefacts. Future work will therefore extend the algorithm with a reflection-tracking layer: (i) each image source will be assigned a persistent identifier derived from its mirror vector $( m _ { x } , m _ { y } , m _ { z } )$ , allowing its parameters to evolve smoothly, and (ii) a soft-selection gate will fade paths in and out according to energy or delay thresholds. Collectively, these two measures are expected to ensure artefact-free extrapolation along moving listener or source trajectories. 

# 5. CONCLUSIONS

This paper has presented a method for higher-order Ambisonic spatial room impulse response (SRIR) extrapolation from a single measurement, where the room geometry and source−receiver positions are known. The method uses the room geometry information along with the image source method to simulate the direction-of-arrival, time-of-arrival, and distance of the direct sound and early reflections of the original and target positions, before calculating the difference. The subspace decomposition method is used to separate out the salient part of the spatial room impulse response measurement from the diffuse part. The direct sound and early reflections are then windowed out from the salient part of the measurement, processed (to the target time-ofarrival, gain and direction-of-arrival), and summed back into the response. 

The proposed method has been evaluated numerically by comparing a measurement at an original source−receiver posi-

tion and an extrapolated version of the measurement to a separate measurement made at the target source−receiver position. The method has been shown to effectively reproduce the correct direct sound, and to somewhat effectively reproduce some of the first early reflections, though errors exist. Likely, these errors stem from where the image source and the measurement are mismatched. 

Future work will look to improve the methodology through tuning of the geometry and source−receiver position parameters used in the image source method by comparing the measurement and image-source simulations. Also, by including sourcedirectivity in the model. The method will also be more thoroughly evaluated numerically, as well as perceptually. 

A Matlab implementation of the presented SRIR extrapolation method, srir_extrap_imgSrc_subspace_LAC.m, along with a demonstration script which reproduces the figures presented in this paper, is available to download at https:// github.com/ZhenxianLi/srir_extrap_LAC2025_ZL_ TM. 

# 6. REFERENCES



[1] T. J. MacGillivray, W. Ellis, and S. D. Pye, “The resolution integral: Visual and computational approaches to characterizing ultrasound images”, Physics in Medicine and Biology, vol. 55, no. 17, pp. 5067–5088, 2010. DOI: 10 . 1088 / 0031 - 9155 / 55 / 17 / 012. (visited on 04/12/2023). 





[2] J. S. Bradley, H. Sato, and M. Picard, “On the importance of early reflections for speech in rooms”, The Journal of the Acoustical Society of America, vol. 113, no. 6, pp. 3233–3244, 2003. 





[3] D. Khaykin and B. Rafaely, “Acoustic analysis by spherical microphone array processing of room impulse responses”, J. Acoust. Soc. Am., vol. 132, no. 1, pp. 261– 270, 2012. DOI: 10.1121/1.4726012. 





[4] P. Stitt, E. Hendrickx, J.-C. Messonnier, and B. Katz, “The role of head tracking in binaural rendering”, in 29th Tonmeistertagung, International VDT Convention, 2016. 





[5] B. Rakerd and W. M. Hartmann, “Localization of sound in rooms. v. binaural coherence and human sensitivity to interaural time differences in noise”, J. Acoust. Soc. Am., vol. 128, no. 5, pp. 3052–3063, 2010. DOI: 10.1121/ 1.3493447. (visited on 08/17/2023). 





[6] J. M. Arend, S. V. A. Garí, C. Schissler, F. Klein, and P. W. Robinson, “Six-degrees-of-freedom parametric spatial audio based on one monaural room impulse response”, Journal of the Audio Engineering Society, vol. 69, no. 7, pp. 557–575, 2021. DOI: 10 . 17743 / jaes . 2021 . 0009. (visited on 04/26/2023). 





[7] I. Tsunokuni, K. Kurokawa, H. Matsuhashi, Y. Ikeda, and N. Osaka, “Spatial extrapolation of early room impulse responses in local area using sparse equivalent sources and image source method”, Applied Acoustics, vol. 179, p. 108 027, 2021. 





[8] F. Zotter and M. Frank, Ambisonics: A Practical 3D Audio Theory for Recording, Studio Production, Sound Reinforcement, and Virtual Reality (Springer Topics in Signal Processing). Cham: Springer International Publishing, 2019, vol. 19, ISBN: 978-3-030-17206-0 978-3-030- 17207-7. DOI: 10.1007/978- 3- 030- 17207- 7. (visited on 06/14/2023). 





[9] L. McCormack, A. Politis, T. McKenzie, C. Hold, and V. Pulkki, “Object-based six-degrees-of-freedom rendering of sound scenes captured with multiple ambisonic receivers”, Journal of the Audio Engineering Society, vol. 70, no. 5, pp. 355–372, May 11, 2022. DOI: 10 . 17743 / jaes.2022.0010. (visited on 06/27/2023). 





[10] T. Deppisch, S. V. A. Garí, P. Calamia, and J. Ahrens, “Direct and residual subspace decomposition of spatial room impulse responses”, IEEE/ACM Transactions on Audio, Speech, and Language Processing, vol. 31, pp. 927–942, 2023. 





[11] C. Kirsch, J. Poppitz, T. Wendt, S. Van De Par, and S. D. Ewert, “Spatial Resolution of Late Reverberation in Virtual Acoustic Environments”, en, Trends in Hearing, vol. 25, p. 23 312 165 211 054 924, Jan. 2021. DOI: 10.1177/ 23312165211054924. (visited on 03/11/2025). 





[12] L. Savioja and U. P. Svensson, “Overview of geometrical room acoustic modeling techniques”, en, The Journal of the Acoustical Society of America, vol. 138, no. 2, pp. 708–730, Aug. 2015. DOI: 10.1121/1.4926438. (visited on 03/11/2025). 





[13] T. McKenzie, S. J. Schlecht, and V. Pulkki, “Auralisation of the transition between coupled rooms”, in Int. Conf. on Immersive and 3D Audio, Online: IEEE, Sep. 2021, pp. 1–9. DOI: 10.1109/I3DA48870.2021.9610955. 





[14] J. B. Allen and D. A. Berkley, “Image method for efficiently simulating small-room acoustics”, The Journal of the Acoustical Society of America, vol. 65, no. 4, pp. 943– 950, Apr. 1979, ISSN: 0001-4966. DOI: 10.1121/1. 382599. [Online]. Available: https://doi.org/ 10.1121/1.382599 (visited on 03/16/2025). 





[15] T. McKenzie, L. McCormack, and C. Hold, “Dataset of spatial room impulse responses in a variable acoustics room for six degrees-of-freedom rendering and analysis”, in arXiv preprint, 2021, pp. 1–3. DOI: 10.48550/arXiv. 2111.11882. arXiv: 2111.11882. 





[16] M. Zaunschirm, C. Schörkhuber, and R. Höldrich, “Binaural rendering of Ambisonic signals by head-related impulse response time alignment and a diffuseness constraint”, J. Acoust. Soc. Am., vol. 143, no. 6, pp. 3616–3627, 2018. DOI: 10.1121/1.5040489. 





[17] T. McKenzie, D. T. Murphy, and G. C. Kearney, “Diffusefield equalisation of binaural Ambisonic rendering”, Appl. Sci., vol. 8, no. 10, Oct. 2018. DOI: 10.3390/app8101956. 





[18] B. Bernschütz, “A spherical far field HRIR / HRTF compilation of the Neumann KU 100”, in Fortschritte der Akustik – AIA-DAGA 2013, 2013, pp. 592–595. 





[19] T. McKenzie and F. Brinkmann, “Toward an Improved Auditory Model for Predicting Binaural Coloration”, J. Audio Eng. Soc., no. Accepted for publication, 2025. DOI: 10.17743/jaes.2022.0192. 





[20] A. Politis, “Microphone array processing for parametric spatial audio techniques”, PhD Thesis, Aalto University, 2016. 

