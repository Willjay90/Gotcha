# Indoor Guidance Application with AR
![ios12+](https://img.shields.io/badge/ios-12%2B-blue.svg)
![swift4+](https://img.shields.io/badge/swift-4%2B-orange.svg)
![arkit2](https://img.shields.io/badge/arkit-2-brightgreen.svg)

This project is motivated by [Google Map AR extention](https://youtu.be/ogfYd705cRs?t=5098) in Google I/O 18 and [Sharing AR Experience](https://www.apple.com/newsroom/2018/06/apple-unveils-arkit-2/?videoid=0e9ddba360be9dd77ac4881ea2fa6cdb) with ARKit 2 in WWDC 2018. 
The goal is to create a indoor guidance system to help users locate items in a grocery store. 

<img src="https://github.com/Willjay90/Gotcha/blob/master/resources/GoogleMapAR.png" width="800" height="450"/> <img src="https://github.com/Willjay90/Gotcha/blob/master/resources/SharingARWorld.png" width="800" height="450"/>


---

## Functionality

- Object recognition with [Inception V3 model](https://developer.apple.com/machine-learning/model-details/Inception-v3.txt) using [CoreML](https://developer.apple.com/documentation/coreml) library.
- Sharing ARWorld with one another using [MultipeerConnectivity](MultipeerConnectivity).

## Challenges
- [Show the navigation path](https://stackoverflow.com/questions/53530244/how-to-make-an-scnnode-facing-toward-aranchor)
- Delay when sharing ARWorld

## Demo
<img src="https://github.com/Willjay90/Gotcha/blob/master/resources/FirstView.png" width="250" height="400"/><img src="https://github.com/Willjay90/Gotcha/blob/master/resources/Host.gif" width="250" height="400"/> <img src="https://github.com/Willjay90/Gotcha/blob/master/resources/User.gif" width="250" height="400"/>


## References
- [Building Your First AR Experience](https://developer.apple.com/documentation/arkit/building_your_first_ar_experience)
- [Creating a Multiuser AR Experience](https://developer.apple.com/documentation/arkit/creating_a_multiuser_ar_experience)
- [Bluetoothed ARKit 2.0 with ARWorldMap!](https://github.com/simformsolutions/ARKit2.0-Prototype)
- [Using Vision in Real Time with ARKit](https://github.com/eduDorus/PAWI/tree/master/prototypes/UsingVisionInRealTimeWithARKit)
