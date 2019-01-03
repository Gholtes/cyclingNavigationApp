//
//  NavViewControlerViewController.swift
//  Crow Flies v1
//
//  Created by Grant Holtes on 29/10/18.
//  Copyright © 2018 Grant Holtes. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation
import Foundation

class NavViewControler: UIViewController, UITextFieldDelegate, CLLocationManagerDelegate {
    
    //Location services
    //User location
    var locationManager = CLLocationManager()
    //Init vars
    var Destination = CLLocation(latitude: 0, longitude: 0)
    var userInput = ""
    var userLocation = CLLocation(latitude: 0, longitude: 0)
    var userHeading: Double = 0
    var previousUserLocation = CLLocation(latitude: 0, longitude: 0)
    var distanceFromDestination = 0.0
    var thresholdNearDestinationDistance = 0.5 //increase verbal instructions when user is within 500m
    var thresholdTimeSinceLastSpeak: Double = 120 //Max time between instructions
    var timeSinceLastSpeak = 9999999.0
    var instructionCode: Int = 0 //Init code
    var previousGivenInstructionCode: Int = 1 //Init code
    var arrived = false
    
    //Delay period
    var delay: Double = 15
    //define timer
    var timer = Timer()

    //UI vars
    @IBOutlet weak var distanceLabel: UILabel!

    @IBOutlet weak var destinationLabel: UILabel!
    @IBOutlet weak var directionLabel: UILabel!
    //Image
    @IBOutlet weak var arrow: UIImageView!
    
    //Audio session
    let session = AVAudioSession.sharedInstance()
    
    //Call counters, max call declaration
    var recursiveCalls:Int = 0
    let maxRecursiveCalls = 2
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //init audio sessions
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        print("viewWillAppear")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("In Nav:")
        print(Destination)
        print(userLocation)
        
        //update screen
        destinationLabel.text = userInput
        directionLabel.text = ""
        
        //Get distance in metres, convert to km with 2 dp
        let Distance = getDistance(userLocation: userLocation, Destination: Destination)
        distanceLabel.text = String(Distance) + "km"
        
        // For use when the app is open & in the background
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        
        
        // If location services is enabled get the users location
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self //Set delegate
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            //Heading manager
            locationManager.startUpdatingHeading()
        }
        //Load user location in background
        self.recursiveCalls = 0
        locateUserSync()
        
        //Tell the user which way to go
        var Heading = compassHeadingToDestination(userLocation: userLocation, Destination: Destination)
        if (Distance < 0.1) {
            //Cheack if destination is close by
            sayArrived()
            arrived = true
        }
        else {
            //Loaction is further away
            sayInitialHeading(Distance: Distance, compassHeadingToDestination: Heading)
            arrived = false
        }
        
        //Start timer and enter main loop
        if (arrived == false) {
            startTimer()
        }
        

    }
    
    //MARK: Location_Utils
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //get location
        let userLocation:CLLocation = locations[0] as CLLocation
        //Get heading
        userHeading = Double(manager.heading?.magneticHeading ?? 0)
        
        
        
        // Call stopUpdatingLocation() to stop listening for location updates,
        // other wise this function will be called every time when user location changes.
        
//         manager.stopUpdatingLocation()

        print("user latitude = \(userLocation.coordinate.latitude)")
        print("user longitude = \(userLocation.coordinate.longitude)")
        print("heading = \(userHeading)")
        //Animate arrow:
        //Get the required heading
        let requiredHeading = compassHeadingToDestination(userLocation: userLocation, Destination: Destination)
        print("required Heading = \(requiredHeading)")
        let rotationAngle = requiredHeading - userHeading
        print("rotation = \(rotationAngle)")
        //Animate
        UIView.animate(withDuration: 0.75) {
            let rotationAngle = rotationAngle * Double.pi / 180 // convert from degrees to radians
            self.arrow.transform = CGAffineTransform(rotationAngle: CGFloat(rotationAngle)) // rotate the picture
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }
    
    func locateUser() {
        //Doesn't return value as request takes time - asynchronicity
        //Updates global var userLocation
        
        locationManager.requestLocation()
        if let lastLocation = self.locationManager.location {
            var userLocation = lastLocation
            var recursiveCalls = 0
        }
        else {
            print("Location not found")
            //Retain last user location
            
            if (recursiveCalls < maxRecursiveCalls) {
                self.recursiveCalls+=1
                print(recursiveCalls)
                //Wait
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    //Try find the user again
                    self.locateUser()
                })
            }
        }
    }
    
    func locateUserSync() {
        //Waits until user is found TODO what if user isnt found?
        //Updates global var userLocation
        
        let group = DispatchGroup()
        group.enter()
        
        // avoid deadlocks by not using .main queue here
        DispatchQueue.global().async {
            self.locationManager.requestLocation()
            if let lastLocation = self.locationManager.location {
                self.userLocation = lastLocation
                self.recursiveCalls = 0
            }
            else {
                print("Location not found")
                //Retain last user location
                
                if (self.recursiveCalls < self.maxRecursiveCalls) {
                    self.recursiveCalls+=1
                    print(self.recursiveCalls)
                    //Wait
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                        //Try find the user again after 1 second
                        self.locateUserSync()
                    })
                }
            }
            //If complete, leave
            group.leave()
        }
        
        // wait for async process to complete
        group.wait()
        
    }
    
    //Mark: Direction Utils
    func deviationFromHeading(userLocation: CLLocation, Destination: CLLocation) -> Double {
        //Return the differenec in the users current heading and the compass heading from userLocation to Destination
        //Deviation is in degrees clockwise from reqired heading
        let userCourse = userLocation.course
//        let userCourse = 280.0 //Debug heading
        var requiredHeading = compassHeadingToDestination(userLocation: userLocation, Destination: Destination)
        //Covert required heading to course style:
        if (requiredHeading < 0) {
            requiredHeading = 360 + requiredHeading
        }
        //Calc Deviation
        var Deviation = userCourse - requiredHeading
        //make more intuitive, snap to deviation <= 180
        if (Deviation > 180) {
            Deviation = Deviation - 360
        }
        else if (Deviation < -180) {
            Deviation = 360 + Deviation
        }
        print("DEVIATION")
        print(Deviation)
        return Deviation
    }
    
    func compassHeadingToDestination(userLocation: CLLocation, Destination: CLLocation) -> Double {
        //Return the compass heading from userLocation to Destination
        //Technically this is the forward azimuth but hopefully the user wont be cycling
        //far enough for the earth's curviture to matter!
        
        //Convert to radians
        let y1 = userLocation.coordinate.longitude * Double.pi / 180
        let x1 = userLocation.coordinate.latitude * Double.pi / 180
        let y2 = Destination.coordinate.longitude * Double.pi / 180
        let x2 = Destination.coordinate.latitude * Double.pi / 180
        
        let y = sin(y2 - y1) * cos(x2)
        let x = cos(x1) * sin(x2) -
            sin(x1) * cos(x2) * cos(y2 - y1);
        //Convert to degrees
        let Heading = atan2(y, x) * 180 / Double.pi
        return Heading
    }
    
    func getDistance(userLocation: CLLocation, Destination: CLLocation) -> Double {
        //Get distance in km
        distanceFromDestination = userLocation.distance(from: Destination)
        return Double(round(distanceFromDestination / 100) / 10)
    }
    
    func doSpeak(userLocation: CLLocation, previousUserLocation: CLLocation, timeSinceLastSpeak: Double, instructionCode: Int, previousGivenInstructionCode: Int, Distance: Double) -> Bool {
        //Base case = do not speak
        var Speak = false
        //Decide if to speak or not using a series of tests
        //When to speak:
        //- A constant time since the last verbal instruction has passed
        if (timeSinceLastSpeak >= thresholdTimeSinceLastSpeak) {
            Speak = true
        }
        //- The user is within a set distance of their destination
        if (Distance <= thresholdNearDestinationDistance) {
            Speak = true
        }
        //- The direction instruction is different to the last one given
        if (instructionCode != previousGivenInstructionCode) {
            Speak = true
        }
        
        //--ENFORCE: User has moved between instructions
        let Movement = userLocation.distance(from: previousUserLocation)
        //Threshold movement = 10m to account for GPS error
        if (Movement < 10){
            Speak = false
        }
        
        return Speak
        
    }
    //MARK: Dictation utils
    func say(inputString: String) {
        let utterance = AVSpeechUtterance(string: inputString)
        //Change voice
        //utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
    
    func makeDeviationDistanceString(Deviation: Double, Distance: Double) -> String {
        var str = "Your destination is " + String(Distance) + " kilometres away. "
        //Only 90 degree currently
        //Deviation is in degrees clockwise from reqired heading
        //Convert to a change in direction:
        var direction = ""
        let Deviation = -1 * Deviation
        if (Deviation < 45 && Deviation >= -45) {
            //Continue straight
            direction = "Continue in your current direction."
            str = str + direction
            instructionCode = 1
        }
        else if (Deviation > 45 && Deviation <= 135) {
            // Turn right
            direction = "Bear right."
            str = str + direction
            instructionCode = 2
        }
        else if (Deviation < -45  && Deviation >= -135) {
            // Turn left
            direction = "Bear Left."
            str = str + direction
            instructionCode = 3
        }
        else {
            //Turn around
            direction = "Your destination is behind you."
            str = str + direction
            instructionCode = 4
        }
        //Update onscreen text
        directionLabel.text = direction
        //Return string
        return direction
    }
    
    func sayArrived() {
        let str = "Your destination is within 100 metres"
         //Dictate
        say(inputString: str)
        print(str)
    }
    
    func sayInitialHeading(Distance: Double, compassHeadingToDestination: Double) {
        var str = "Your destination is " + String(Distance) + " kilometres "
        var printStr = "Navigate "
        //Only 90 degree TODO
        if (compassHeadingToDestination <= 45 && compassHeadingToDestination > -45) {
            //Continue straight
            str = str + "north."
            printStr = printStr + "north"
        }
        else if (compassHeadingToDestination >= 45 && compassHeadingToDestination < 135) {
            // Turn right
            str = str + "east"
            printStr = printStr + "east"
        }
        else if (compassHeadingToDestination <= -45  && compassHeadingToDestination > -135) {
            // Turn left
            str = str + "west"
            printStr = printStr + "west"
        }
        else {
            //Turn around
            str = str + "south"
            printStr = printStr + "south"
        }
        //Dictate
        say(inputString: str)
        directionLabel.text = printStr
        print(str)
    }
    
    //MARK: Main Loop
    func startTimer() {
        //Runs main loop every "delay" seconds
        timer.invalidate()   // just in case you had existing `Timer`, `invalidate` it before we lose our reference to it
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { [weak self] _ in
            self?.mainLoop()
        }
    }
    
    func stopTimer() {
        //exits the main loop
        timer.invalidate()
    }
    
    func mainLoop(){
        self.recursiveCalls = 0
        locateUserSync() //Ensure location is found if possible
        //get required variables
        let deviation = deviationFromHeading(userLocation: userLocation, Destination: Destination)
        let Distance = getDistance(userLocation: userLocation, Destination: Destination)
        distanceLabel.text = String(Distance) + "km"
        //say info to user
        if (Distance < 0.1) {
            //If within 100m, use arrived message
            sayArrived()
            arrived = true
            //Exit main loop timer
            stopTimer()
        }
        else {
            //Form dirction string, update instructionCode
            let direction = makeDeviationDistanceString(Deviation: deviation, Distance: Distance)
            //check if instructions should be given
            if (doSpeak(userLocation: userLocation, previousUserLocation: previousUserLocation, timeSinceLastSpeak: timeSinceLastSpeak, instructionCode: instructionCode, previousGivenInstructionCode: previousGivenInstructionCode, Distance: Distance)){
                
                say(inputString: direction)
                //Update
                previousGivenInstructionCode = instructionCode
                previousUserLocation = userLocation.copy() as! CLLocation
                timeSinceLastSpeak = 0.0
            }
            else {
                //add to timeSinceLastSpeak
                timeSinceLastSpeak = timeSinceLastSpeak + delay
            }
            arrived = false
        }
    }
    // MARK: Actions
    
    @IBAction func backButton(_ sender: UIButton) {
        // Go Back to menu screen
        print("Back action initiated")
        //Exit main loop
        stopTimer()
        //Set arrived bool to false for next trip
        arrived = false
        //Segue
        try? session.setActive(false)
        navigationController?.popViewController(animated: true)
        dismiss(animated: true, completion: nil)
    }
    
}
