//
//  APIClient.swift
//  FirstAtWellsFargo
//
//  Created by Larry on 3/13/17.
//  Copyright © 2017 Larry Nguyen. All rights reserved.
//

import Foundation

public let TRENetworkingErrorDomain = " Com.Wellsfargo.networkError"
public let MissingHTTPResponseError : Int = 20
public let UnexpectedResponseError: Int = 10

typealias JSON = [String: AnyObject]
typealias JSONTaskCompletion = (JSON?,HTTPURLResponse?,NSError?) -> Void
typealias JSONTask = URLSessionDataTask

enum APIResult<T>{
    case success(T)
    case failure(Error)
    
}

protocol JSONDecodable {
    init?(JSON: [String: AnyObject])
    
}

protocol Endpoint {
    var baseURL:URL {get}
    var path: String {get}
    var request: URLRequest {get}
}

protocol APIClient{
    var configuration: URLSessionConfiguration {get}
    var session: URLSession {get}
    
    init(config:URLSessionConfiguration, APIKey:String)
    func JSONTaskWithRequest(_ request: URLRequest,completion: @escaping JSONTaskCompletion) -> JSONTask
    func fetch<T: JSONDecodable>(_ request: URLRequest, parse: @escaping (JSON) -> T?, completion: @escaping (APIResult<T>) -> Void)
}

extension APIClient{
    func JSONTaskWithRequest(_ request: URLRequest, completion: @escaping JSONTaskCompletion) -> JSONTask {
        let task = session.dataTask(with: request, completionHandler:{ data, response, error in
            guard let HTTPResponse = response as? HTTPURLResponse  else {
                let userInfo = [ NSLocalizedDescriptionKey: NSLocalizedString("Missing HTTP Response", comment: "This is not good")]
                let error = NSError(domain: TRENetworkingErrorDomain, code: MissingHTTPResponseError, userInfo: userInfo)
                completion(nil, nil, error)
                return
            }
            
            if data == nil{
                if let error = error {
                    completion(nil, HTTPResponse, error as NSError?)
                }
            } else {
                switch  HTTPResponse.statusCode{
                case 200:
                    do {
                        let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as?[String:AnyObject]
                        completion(json, HTTPResponse, nil)
                    } catch let error as NSError {
                        completion(nil, HTTPResponse,error)
                        
                    }
                    
                 default: print(" Received HTTP response with code \(HTTPResponse.statusCode) - not handled")
                }
               
            }
            
            
            
        })
        return task
    }
    
    func fetch<T>(_ request: URLRequest, parse: @escaping (JSON) -> T?, completion: @escaping (APIResult<T>) -> Void){
        
        let task = JSONTaskWithRequest(request) {
            json, response, error in
            
            DispatchQueue.main.async {
                guard let json = json else {
                    if let error = error {
                        completion(APIResult.failure(error))
                    } else {
                        //TODO: - implementing error handling
                    }
                    return
                }
                
                if let value = parse(json){
                    completion(APIResult.success(value))
                    
                } else{
                    let error = NSError(domain: TRENetworkingErrorDomain, code: UnexpectedResponseError, userInfo: nil)
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
}
