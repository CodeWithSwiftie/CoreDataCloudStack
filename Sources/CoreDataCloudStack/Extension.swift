//
//  Extension.swift
//  
//
//  Created by Vlad Tretyakov on 17.05.2023.
//

import CoreData

extension PersistenceManager {
    static func loadModel(bundle: Bundle?, use url: URL?, modelName: String) -> NSManagedObjectModel? {
        
        if bundle == nil, let url {
            return NSManagedObjectModel(contentsOf: url)
        }
        
        else if let bundle, let fileURL = bundle.url(forResource: modelName, withExtension: "momd") {
            return NSManagedObjectModel(contentsOf: fileURL)
        }
        
        return nil
    }
}

extension NSManagedObjectContext {

    /// Only performs a save if there are changes to commit.
    /// - Returns: `true` if a save was needed. Otherwise, `false`.
    @discardableResult public func saveIfNeeded() throws -> Bool {
        guard hasChanges else { return false }
        try save()
        return true
    }
}
