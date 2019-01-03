//
//  ViewController.swift
//  Crow Flies v1
//
//  Created by Grant Holtes on 28/10/18.
//  Copyright © 2018 Grant Holtes. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate {

    // MARK: Properties
    @IBOutlet weak var searchBar: UISearchBar!
    
    //Location services
    //Reverse Geocoding
    lazy var geocoder = CLGeocoder()
    //User location
    var locationManager = CLLocationManager()
    //Destination and user locations init
    var Destination = CLLocation(latitude: 0, longitude: 0)
    var userLocation = CLLocation(latitude: 0, longitude: 0)
    var userInput = "No Address Input"
    
    //Call counters, max call declaration
    var recursiveCalls:Int = 0
    var recursiveCallsDest:Int = 0
    let maxRecursiveCalls = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        self.streetTextField.delegate = self
        
        self.searchBar.delegate = self
        
        // For use when the app is open & in the background
        locationManager.requestWhenInUseAuthorization()

        // If location services is enabled get the users location
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        //Load user location
        locateUser()
        print("MAIN")
        print(userLocation)
        print("_______")
        
    }
    //MARK: Location_Utils
    func processResponse(withPlacemarks placemarks: [CLPlacemark]?, error: Error?) -> CLLocation {

        if let error = error {
            print("Unable to Forward Geocode Address (\(error))")
            
        }
        else {
            var location: CLLocation?
            
            if let placemarks = placemarks, placemarks.count > 0 {
                location = placemarks.first?.location
            }
            
            if let location = location {
                return location
                
            }
            else {
              //No matching coordinates found, return null island!
                return CLLocation(latitude: 0, longitude: 0)
            }
            //No matching coordinates found, return null island!
            return CLLocation(latitude: 0, longitude: 0)
        }
        //No matching coordinates found, return null island!
        return CLLocation(latitude: 0, longitude: 0)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let currrentLocation:CLLocation = locations[0] as CLLocation
        userLocation = currrentLocation
        //Stop listening for location updates
        manager.stopUpdatingLocation()
        
        print("user latitude = \(currrentLocation.coordinate.latitude)")
        print("user longitude = \(currrentLocation.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }
    
    
    func locateUser() {
        //Doesn't return value as request takes time - asynchronicity
        //Updates global var userLocation
        //
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
    
    //MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }
    
    override func prepare(for segue:
        UIStoryboardSegue, sender: Any?) {
        //Declare what data navControlView should inherit
        let destVC : NavViewControler = segue.destination as! NavViewControler
        destVC.Destination = Destination
        destVC.userLocation = userLocation
        destVC.userInput = userInput
    }
    
    func safeSegue() {
        //Check if destination is found
        //TODO - limit recusion, add error messages to UI
        
        if (Destination.coordinate.longitude == 0.0 && Destination.coordinate.latitude == 0.0){
            if (recursiveCallsDest < maxRecursiveCalls) {
                self.recursiveCallsDest+=1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    self.safeSegue()
                })
            }
            else {
                print("Geocoding Failed")
            }
        }
        else {
            self.performSegue(withIdentifier: "navSegue", sender: self)
        }
    }
    
    //MARK: Actions
    func geocodeAndSegue(userInput: String) {
        //GO BUTTON
        //Reset Destination
        Destination = CLLocation(latitude: 0, longitude: 0)
        
        // Geocode Address String
        geocoder.geocodeAddressString(userInput) { (placemarks, error) in
            // Process Response
            self.Destination = self.processResponse(withPlacemarks: placemarks, error: error)
        }
        //segue with delay for loading
        safeSegue()
    }
    

    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("GO pressed")
        userInput = searchBar.text!
        self.searchBar.endEditing(true)
        geocodeAndSegue(userInput: userInput)
    }
}
