//
//  Util.swift
//  pickerApp
//
//  Created by Conan Moriarty on 10/08/2017.
//  Copyright © 2017 Conan Moriarty. All rights reserved.
//

import Foundation

func println(_ s:String) {
  let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/dump.txt"
  
  print(s)
  var dump = ""
  if FileManager.default.fileExists(atPath: path) {
    dump =  try! String(contentsOfFile: path, encoding: String.Encoding.utf8)
  }
  do {
    // Write to the file
    try  "\(dump)\n\(s)".write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
    
  } catch let error as NSError {
    print("Failed writing to log file: \(path), Error: " + error.localizedDescription)
  }
}
