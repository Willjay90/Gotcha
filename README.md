# Indoor Guidance Application with Augmented Reality
![ios12+](https://img.shields.io/badge/ios-12%2B-blue.svg)
![swift4+](https://img.shields.io/badge/swift-4%2B-orange.svg)
![arkit2](https://img.shields.io/badge/arkit-2-brightgreen.svg)

This project is motivated by [Google Map AR extention](https://youtu.be/ogfYd705cRs?t=5098) in Google I/O 18 and [Sharing AR Experience](https://www.apple.com/newsroom/2018/06/apple-unveils-arkit-2/?videoid=0e9ddba360be9dd77ac4881ea2fa6cdb) with ARKit 2 in WWDC 2018. 
The goal is to create a indoor guidance system to help users locate items in a grocery store. 


---

## What have been done

- Tag and retrieve real world items with Augemented Reality in our app. 

- Object recognition with [Inception V3 model](https://developer.apple.com/machine-learning/model-details/Inception-v3.txt) using [CoreML](https://developer.apple.com/documentation/coreml).
- Share ARWorldMap with one another using [MultipeerConnectivity](MultipeerConnectivity).

## Challenges
- Can we share a large ARWorldMap?
- Inception V3 is not tailored for items in a grocery store, is there any better model, or we have to train it ourselves.



## Demo
[![Demo_Video](https://github.com/Willjay90/Gotcha/blob/master/resources/youtube_demo.png)](https://youtu.be/jRBHVMcQzR0)

## Hint
- single click on screen to show the item list
- double click to dismiss the item list



## References
- [Building Your First AR Experience](https://developer.apple.com/documentation/arkit/building_your_first_ar_experience)
- [Creating a Multiuser AR Experience](https://developer.apple.com/documentation/arkit/creating_a_multiuser_ar_experience)
- [Bluetoothed ARKit 2.0 with ARWorldMap!](https://github.com/simformsolutions/ARKit2.0-Prototype)
- [Using Vision in Real Time with ARKit](https://github.com/eduDorus/PAWI/tree/master/prototypes/UsingVisionInRealTimeWithARKit)
