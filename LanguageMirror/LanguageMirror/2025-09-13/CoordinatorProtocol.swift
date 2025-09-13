//
//  coordinator_protocol.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    func start() -> UINavigationController
}
