//
//  RideAcceptedDetailsViewController.swift
//  Uber
//
//  Created by Anil Allewar on 12/30/15.
//  Copyright © 2015 Parse. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class RideAcceptedDetailsViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {

    var currentAcceptedRide:RideData?
    
    @IBOutlet var acceptedRideMapView: MKMapView!
   
    @IBOutlet var searchBar: UISearchBar!
    
    @IBOutlet var tripStartButton: UIButton!
    
    let locationManager = CLLocationManager()
    
    // Used for displaying the search results
    var autoCompleteTableView:UITableView!
    
    var searchResults = [AddressSearch]()
    
    var selectedAddressIndex:Int = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Load map with pickup address
        self.setupInitialMap()
        
        // Handle the search bar click event
        self.searchBar.delegate = self
        
        // Disable the start trip button
        self.tripStartButton.enabled = false
        self.tripStartButton.userInteractionEnabled = false
        
        self.autoCompleteTableView = UITableView(frame: CGRectMake(10, self.searchBar.center.y + self.searchBar.frame.height, self.searchBar.frame.width, 120), style: .Plain)
        
        // Initialize the auto-complete table
        self.autoCompleteTableView.delegate = self
        self.autoCompleteTableView.dataSource = self
        self.autoCompleteTableView.scrollEnabled = true
        self.autoCompleteTableView.hidden = true
        
        self.view.addSubview(self.autoCompleteTableView)
    }
    
    private func setupInitialMap() {
        // Do any additional setup after loading the view.
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        
        self.acceptedRideMapView.showsUserLocation = true
        self.locationManager.startUpdatingLocation()
        
        self.acceptedRideMapView.delegate = self
        
        // Define zoom level
        let latDelta:CLLocationDegrees = 0.02
        let longDelta:CLLocationDegrees = 0.02
        
        let mkSpan = MKCoordinateSpanMake(latDelta, longDelta)
        
        let mkRegion = MKCoordinateRegionMake(self.currentAcceptedRide!.getCoordinates(), mkSpan)
        
        self.acceptedRideMapView.setRegion(mkRegion, animated: true)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = self.currentAcceptedRide!.getCoordinates()
        annotation.title = "PickUp Address"
        
        annotation.subtitle = self.currentAcceptedRide!.getAddress()
        
        self.acceptedRideMapView.addAnnotation(annotation)
        
        self.acceptedRideMapView.selectAnnotation(annotation, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func tripButtonClicked(sender: AnyObject) {
        print("Trip start button clicked")
        print("Selected index is: \(self.selectedAddressIndex) and the address is: \(self.searchResults[self.selectedAddressIndex].addressText) and the coordinates are: \(self.searchResults[self.selectedAddressIndex].addressCoordinate)")
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let currentUserCoordinate = locations[0].coordinate
        
        let destinationCoordinate = self.currentAcceptedRide!.getCoordinates()
        
        let directionsRequest = MKDirectionsRequest()
        
        let markCurrentAddress = MKPlacemark(coordinate: CLLocationCoordinate2DMake(currentUserCoordinate.latitude, currentUserCoordinate.longitude), addressDictionary: nil)
        let markPickupAddress = MKPlacemark(coordinate: CLLocationCoordinate2DMake(destinationCoordinate.latitude, destinationCoordinate.longitude), addressDictionary: nil)
        
        directionsRequest.source = MKMapItem(placemark: markCurrentAddress)
        directionsRequest.destination = MKMapItem(placemark: markPickupAddress)
        directionsRequest.transportType = MKDirectionsTransportType.Automobile
        let directions = MKDirections(request: directionsRequest)
        
        directions.calculateDirectionsWithCompletionHandler { (response, error) -> Void in
            if error != nil {
                self.showAlert("Error calculating directions", message: (error?.localizedDescription)!)
            } else {
                if let response = response {
                    if let calculatedRoute = response.routes[0] as? MKRoute {
                        self.acceptedRideMapView.addOverlay(calculatedRoute.polyline)
                        // Stop updating locations once the initial overlay is laid
                        self.locationManager.stopUpdatingLocation()
                    }
                }
            }
        }
    }
    
    // How to render the line overlay on the map
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let polyLineRenderer = MKPolylineRenderer(overlay: overlay)
            polyLineRenderer.strokeColor = UIColor.blueColor()
            polyLineRenderer.lineWidth = 3
            return polyLineRenderer
        }
        
        // If overlay is not polyline, then need to be handled differently
        return MKOverlayRenderer()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let viewController:RiderFeedTableTableViewController = segue.destinationViewController as! RiderFeedTableTableViewController
        
        viewController.acceptedRideIndex = -1
        self.selectedAddressIndex = -1
    }
    
    func searchBarSearchButtonClicked(searchBarPassed: UISearchBar) {
        
        searchBarPassed.resignFirstResponder()
        
        let localSearchRequest:MKLocalSearchRequest = MKLocalSearchRequest()
        localSearchRequest.naturalLanguageQuery = searchBarPassed.text
        
        let localSearch:MKLocalSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.startWithCompletionHandler { (searchResponse, error) -> Void in
            // Initialize the address selection
            self.selectedAddressIndex = -1
            self.searchResults.removeAll()
            
            if error != nil {
                self.showAlert("Error searching address", message: (error?.localizedDescription)!)
            } else {
                if searchResponse == nil {
                    self.showAlert("No results", message: "No address found which matches the provided address")
                } else {
                    if let mapItems = searchResponse?.mapItems {
                        self.populateAddressSearchResults(mapItems)
                        self.autoCompleteTableView.hidden = false
                    }
                }
                
                // Reload the auto completion table
                self.autoCompleteTableView.reloadData()
            }
        }
    }
    
    private func populateAddressSearchResults (mapItems:[MKMapItem]) -> Void {
        var messageText:String
        
        for mapItem in mapItems {
            messageText = ""
            
            if let subStreet = mapItem.placemark.subThoroughfare {
                messageText += subStreet
            }
            
            if let street = mapItem.placemark.thoroughfare {
                if messageText.characters.count > 0 {
                    messageText += " " + street
                } else {
                    messageText = street
                }
            }
            
            if let locality = mapItem.placemark.locality {
                if messageText.characters.count > 0 {
                    messageText += ", " + locality
                } else {
                    messageText = locality
                }
            }
            
            if let administrativeArea = mapItem.placemark.administrativeArea {
                if messageText.characters.count > 0 {
                    messageText += ", " + administrativeArea
                } else {
                    messageText = administrativeArea
                }
            }
            
            if let postalCode = mapItem.placemark.postalCode {
                if messageText.characters.count > 0 {
                    messageText += ", " + postalCode
                } else {
                    messageText = postalCode
                }
            }
            
            let destinationCoordinates:CLLocationCoordinate2D = CLLocationCoordinate2DMake(mapItem.placemark.location!.coordinate.latitude , mapItem.placemark.location!.coordinate.longitude)
            
            let addressItem = AddressSearch(addressText:messageText, addressCoordinate:destinationCoordinates)
            
            self.searchResults.append(addressItem)

        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.searchResults.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let autoCompleteCellIdentifier = "autoCell"
        
        var cell = tableView.dequeueReusableCellWithIdentifier(autoCompleteCellIdentifier)
        
        if let tableCell = cell {
            tableCell.textLabel?.text = searchResults[indexPath.row].addressText
        } else {
            cell = UITableViewCell(style: .Value1, reuseIdentifier: autoCompleteCellIdentifier)
            cell!.textLabel?.text = searchResults[indexPath.row].addressText
        }
        
        cell!.contentView.layer.borderColor = UIColor.redColor().CGColor
        cell!.contentView.layer.borderWidth = 1.0
        
        return cell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let selectedCell = tableView.cellForRowAtIndexPath(indexPath) {
            self.searchBar.text = selectedCell.textLabel?.text
            self.autoCompleteTableView.hidden = true
            
            // Set the selected address index
            self.selectedAddressIndex = indexPath.row
            
            // Enable the start trip button
            self.tripStartButton.enabled = true
            self.tripStartButton.userInteractionEnabled = true

        }
    }
    
    private func showAlert (title:String, message:String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

struct AddressSearch {
    var addressText:String
    var addressCoordinate:CLLocationCoordinate2D
}