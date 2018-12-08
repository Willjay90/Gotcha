# Indoor Item Locator with ARKit
![ios12+](https://img.shields.io/badge/ios-12%2B-blue.svg)
![swift4+](https://img.shields.io/badge/swift-4%2B-orange.svg)
![arkit2](https://img.shields.io/badge/arkit-2-brightgreen.svg)

A [survey](https://themanifest.com/app-development/popularity-google-maps-trends-navigation-apps-2018
) shows that 77% of smartphone owners regularly use navigation apps. Indeed, with the help of Global Positioning System (GPS), navigation apps can make the directions more in-depth and precise for the users. However, GPS doesn’t work so well indoors. In many games, there are guidance systems (waypoints) that help players find the mission target more easily. With the improvement of mobile phone performance, nowadays smart phone can handle heavy tasks like image processing in 60 fps. We want to use state-of-the-art technology like augmented reality (AR) to make it easier to find items in the store. 

This project is motivated by [Google Map AR extention](https://youtu.be/ogfYd705cRs?t=5098) in Google I/O 18 and [Shared experiences with ARKit 2](https://www.apple.com/newsroom/2018/06/apple-unveils-arkit-2/?videoid=0e9ddba360be9dd77ac4881ea2fa6cdb)  in WWDC 2018. 
The goal is to create a indoor guidance system to help users locate items in a grocery store. 


---

## What have been done

- Tag and retrieve real world items with Augemented Reality in our app. 

- Object recognition with [Inception V3 model](https://developer.apple.com/machine-learning/model-details/Inception-v3.txt) using [CoreML](https://developer.apple.com/documentation/coreml).
- Share ARWorldMap with one another using [MultipeerConnectivity](MultipeerConnectivity).

## Challenges
- How large ARWorldMap can be shared?
- Inception V3 is not tailored for items in a grocery store, is there any better model, or we have to train it ourselves.



## Demo
[![Demo_Video](https://github.com/Willjay90/Gotcha/blob/master/resources/youtube_demo.png)](https://youtu.be/jRBHVMcQzR0)

## Functionalities
Host
- use "+" button to tag item
- "single tap" on screen to show item list
- "double taps" to close item list
- use "save" button to save current worldMap
- use "retrieve" button to retrieve saved worldMap
- when user is nearby, use "share" button to share the worldMap

User after receiving worldMap
- "single tap" on screen to show item list
- "double taps" to close item list
- select item to show waypoint



## References
- [Building Your First AR Experience](https://developer.apple.com/documentation/arkit/building_your_first_ar_experience)
- [Creating a Multiuser AR Experience](https://developer.apple.com/documentation/arkit/creating_a_multiuser_ar_experience)
- [Bluetoothed ARKit 2.0 with ARWorldMap!](https://github.com/simformsolutions/ARKit2.0-Prototype)
- [Using Vision in Real Time with ARKit](https://github.com/eduDorus/PAWI/tree/master/prototypes/UsingVisionInRealTimeWithARKit)
