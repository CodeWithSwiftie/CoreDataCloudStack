//
//  Persistence.swift
//  
//
//  Created by Vlad Tretyakov on 17.05.2023.
//

import CoreData
import CloudKit
import Foundation

// Protocol
protocol Perisistentable {
    associatedtype CloudSyncMode
    associatedtype PersistentStoreType
    
    init(bundle: Bundle, nameModel model: String)
    init(url modelURL: URL, nameModel model: String)
    
    var iCloudSyncMode: CloudSyncMode { get set }
    var persistentStores: [PersistentStoreType] { get set }
    
    func initializate(_ completion: ((NSPersistentCloudKitContainer) -> Void)?)
    func reloadPersistentContainer(_ completion: ((NSPersistentCloudKitContainer) -> Void)?)
    
    var viewContext: NSManagedObjectContext { get }
    var backgroundContext: NSManagedObjectContext { get }
}

open class PersistenceManager: Perisistentable {
    
    static var shared: PersistenceManager! = nil
    
    public var iCloudSyncMode: CloudSyncMode = .none
    public var persistentStores: [PersistentStoreType] = [.sqLite]
    
    public var cloudKitOptionsTransformer: CloudKitOptionsTransformer? = nil
    public var storeTransformer: StoreTransformer? = nil
    
    private let managedModel: NSManagedObjectModel
    private let nameModel: String
    
    private var container: NSPersistentCloudKitContainer? = nil
    public var persistentContainer: NSPersistentCloudKitContainer {
        guard let container else {
            fatalError("PersistentContainer must be set up using `initializate()` before it can be used.")
        }
        
        return container
    }
    
    // Add lazy comment
    lazy var backgroundContext: NSManagedObjectContext = {
        persistentContainer.newBackgroundContext()
    }()
    
    required public init(bundle: Bundle, nameModel model: String) {
        guard let managedModel = Self.loadModel(bundle: bundle, use: nil, modelName: model) else {
            fatalError("Failed to load NSManagedObjectModel from bundle path: \(bundle.bundlePath)")
        }
        
        self.managedModel = managedModel
        self.nameModel = model
        Self.shared = self
    }
    
    required public init(url: URL, nameModel model: String) {
        guard let managedModel = Self.loadModel(bundle: nil, use: url, modelName: model) else {
            fatalError("Failed to load NSManagedObjectModel from url:  \(url.absoluteString)")
        }
        
        self.managedModel = managedModel
        self.nameModel = model
        Self.shared = self
    }
}

extension PersistenceManager {
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    var listOfPersistentStores: [NSPersistentStore] {
        persistentContainer.persistentStoreCoordinator.persistentStores
    }
}

extension PersistenceManager {
    public func initializate(_ completion: ((NSPersistentCloudKitContainer) -> Void)? = nil) {
        container = makeContainer()
        completion?(container!)
    }
    
    public func reloadPersistentContainer(_ completion: ((NSPersistentCloudKitContainer) -> Void)? = nil) {
        container = makeContainer()
        completion?(container!)
    }
}

extension PersistenceManager {
    public enum CloudSyncMode: Equatable, @unchecked Sendable {
        case container(containerID: String, scope: Scope), none
        
        public enum Scope : Int, @unchecked Sendable {
            case `public` = 1, `private` = 2, shared = 3
        }
    }
    
    public struct StoreTransformer {
        let transform: (PersistentStoreType, NSPersistentStoreDescription) -> Void
        public init(_ transform: @escaping (PersistentStoreType, NSPersistentStoreDescription) -> Void) {
            self.transform = transform
        }
    }
    
    public struct CloudKitOptionsTransformer {
        let transform: (NSPersistentCloudKitContainerOptions) -> Void
        public init(_ transform: @escaping (NSPersistentCloudKitContainerOptions) -> Void) {
            self.transform = transform
        }
    }
}

extension PersistenceManager {
    private func makeContainer() -> NSPersistentCloudKitContainer {
        
        let container = {
            if case .container(containerID: let containerID, scope: _) = iCloudSyncMode {
                return NSPersistentCloudKitContainer(name: containerID, managedObjectModel: managedModel)
            }
            
            return NSPersistentCloudKitContainer(name: nameModel, managedObjectModel: managedModel)
        }()
        
        guard !persistentStores.isEmpty else {
            fatalError("Storage type not specified")
        }
        
        let descriptions = persistentStores.map { store in
            let storeDescription = NSPersistentStoreDescription()
            storeDescription.type = store.stringValue
            
            // Set user tranformations for the store description
            if let storeTransformer {
                storeTransformer.transform(store, storeDescription)
            }
            
            if store == .sqLite {
                storeDescription.url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("\(nameModel).sqlite")
                
                // Configure CloudKit
                if case .container(containerID: let containerID, scope: let scope) = iCloudSyncMode {
                    let options = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
                    options.databaseScope = .init(rawValue: scope.rawValue)!
                  
                    // Set default options
                    storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                    storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                    
                    // Set user options
                    if let cloudKitOptionsTransformer {
                        cloudKitOptionsTransformer.transform(options)
                    }
                    
                    storeDescription.cloudKitContainerOptions = options
                } else {
                    // Only works locally
                    storeDescription.cloudKitContainerOptions = nil
                }
            }
            
            return storeDescription
        }
        
        
        container.persistentStoreDescriptions = descriptions
        container.loadPersistentStores { _, error in
            
            if let error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return container
    }
}


extension PersistenceManager {
    public enum PersistentStoreType {
        
        /// Represents the value for NSSQLiteStoreType.
        case sqLite
        
        /// Represents the value for NSBinary1StoreType.
        case binary
        
        /// Represents the value for NSInMemoryStoreType.
        case inMemory
        
        /// Value of the Core Data string constants corresponding to each case.
        var stringValue: String {
            switch self {
            case .sqLite:
                return NSSQLiteStoreType
            case .binary:
                return NSBinaryStoreType
            case .inMemory:
                return NSInMemoryStoreType
            }
        }
    }
}
