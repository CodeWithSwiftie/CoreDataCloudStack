//
//  Enfironment.swift
//  
//
//  Created by Vlad Tretyakov on 16.05.2023.
//

import CoreData

// Injected protocol of the key
protocol InjectionKey {
    associatedtype Value
    static var currentValue: Self.Value { get set }
}

// Storage
public struct PersistenceManagerInjectedValues {
    private static var current = PersistenceManagerInjectedValues()

    static subscript<T>(_ keyPath: KeyPath<PersistenceManagerInjectedValues, T>) -> T {
        get { current[keyPath: keyPath] }
//        set { current[keyPath: keyPath] = newValue }
    }
}


@propertyWrapper
public struct CoreDataInjected<T> {
    private let keyPath: KeyPath<PersistenceManagerInjectedValues, T>
    
    public var wrappedValue: T {
        get { PersistenceManagerInjectedValues[keyPath] }
    }
    
    public init(_ keyPath: KeyPath<PersistenceManagerInjectedValues, T>) {
        guard PersistenceManager.shared != nil else {
            fatalError("The repository has not been initialized. Create a new instance with PersistenceManager.")
        }
        self.keyPath = keyPath
    }
}


extension PersistenceManagerInjectedValues {
    
    public var persistentContainer: NSPersistentCloudKitContainer {
        get { PersistenceManager.shared.persistentContainer }
    }
    
    public var viewContext: NSManagedObjectContext {
        get { PersistenceManager.shared.viewContext }
    }
    
    public var backgroundContext: NSManagedObjectContext {
        get { PersistenceManager.shared.backgroundContext }
    }
    
    public var newBackgroundContext: NSManagedObjectContext {
        get { PersistenceManager.shared.persistentContainer.newBackgroundContext() }
    }
    
    public var persistentStore: NSPersistentStore? {
        get { PersistenceManager.shared.listOfPersistentStores.first(where: { $0.type == NSSQLiteStoreType }) }
    }
    
    public var binaryStore: NSPersistentStore? {
        get { PersistenceManager.shared.listOfPersistentStores.first(where: { $0.type == NSBinaryStoreType }) }
    }
    
    public var temporaryStore: NSPersistentStore? {
        get { PersistenceManager.shared.listOfPersistentStores.first(where: { $0.type == NSInMemoryStoreType })}
    }
}
