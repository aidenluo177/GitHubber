//
//  ListMonitor.swift
//  CoreStore
//
//  Copyright (c) 2015 John Rommel Estropia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import CoreData
#if USE_FRAMEWORKS
    import GCDKit
#endif


// MARK: - ListMonitor

/**
The `ListMonitor` monitors changes to a list of `NSManagedObject` instances. Observers that implement the `ListObserver` protocol may then register themselves to the `ListMonitor`'s `addObserver(_:)` method:

    let monitor = CoreStore.monitorList(
        From(MyPersonEntity),
        Where("title", isEqualTo: "Engineer"),
        OrderBy(.Ascending("lastName"))
    )
    monitor.addObserver(self)

The `ListMonitor` instance needs to be held on (retained) for as long as the list needs to be observed.
Observers registered via `addObserver(_:)` are not retained. `ListMonitor` only keeps a `weak` reference to all observers, thus keeping itself free from retain-cycles.

Lists created with `monitorList(...)` keep a single-section list of objects, where each object can be accessed by index:

    let firstPerson: MyPersonEntity = monitor[0]

Accessing the list with an index above the valid range will throw an exception.

Creating a sectioned-list is also possible with the `monitorSectionedList(...)` method:

    let monitor = CoreStore.monitorSectionedList(
        From(MyPersonEntity),
        SectionBy("age") { "Age \($0)" },
        Where("title", isEqualTo: "Engineer"),
        OrderBy(.Ascending("lastName"))
    )
    monitor.addObserver(self)

Objects from `ListMonitor`s created this way can be accessed either by an `NSIndexPath` or a tuple:

    let indexPath = NSIndexPath(forItem: 3, inSection: 2)
    let person1 = monitor[indexPath]
    let person2 = monitor[2, 3]

In the example above, both `person1` and `person2` will contain the object at section=2, index=3.
*/
@available(OSX, unavailable)
public final class ListMonitor<T: NSManagedObject> {
    
    // MARK: Public (Accessors)
    
    /**
    Returns the object at the given index within the first section. This subscript indexer is typically used for `ListMonitor`s created with `monitorList(_:)`.
    
    - parameter index: the index of the object. Using an index above the valid range will throw an exception.
    - returns: the `NSManagedObject` at the specified index
    */
    public subscript(index: Int) -> T {
        
        return self[0, index]
    }
    
    /**
    Returns the object at the given index, or `nil` if out of bounds. This subscript indexer is typically used for `ListMonitor`s created with `monitorList(_:)`.
    
    - parameter index: the index for the object. Using an index above the valid range will return `nil`.
    - returns: the `NSManagedObject` at the specified index, or `nil` if out of bounds
    */
    public subscript(safeIndex index: Int) -> T? {
        
        return self[safeSectionIndex: 0, safeItemIndex: index]
    }
    
    /**
    Returns the object at the given `sectionIndex` and `itemIndex`. This subscript indexer is typically used for `ListMonitor`s created with `monitorSectionedList(_:)`.
    
    - parameter sectionIndex: the section index for the object. Using a `sectionIndex` with an invalid range will throw an exception.
    - parameter itemIndex: the index for the object within the section. Using an `itemIndex` with an invalid range will throw an exception.
    - returns: the `NSManagedObject` at the specified section and item index
    */
    public subscript(sectionIndex: Int, itemIndex: Int) -> T {
        
        return self[NSIndexPath(indexes: [sectionIndex, itemIndex], length: 2)]
    }
    
    /**
    Returns the object at the given section and item index, or `nil` if out of bounds. This subscript indexer is typically used for `ListMonitor`s created with `monitorSectionedList(_:)`.
    
    - parameter sectionIndex: the section index for the object. Using a `sectionIndex` with an invalid range will return `nil`.
    - parameter itemIndex: the index for the object within the section. Using an `itemIndex` with an invalid range will return `nil`.
    - returns: the `NSManagedObject` at the specified section and item index, or `nil` if out of bounds
    */
    public subscript(safeSectionIndex sectionIndex: Int, safeItemIndex itemIndex: Int) -> T? {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        guard let sections = self.fetchedResultsController.sections
            where sectionIndex < sections.count else {
                
                return nil
        }
        
        let section = sections[sectionIndex]
        guard itemIndex < section.numberOfObjects else {
            
            return nil
        }
        return sections[sectionIndex].objects?[itemIndex] as? T
    }
    
    /**
    Returns the object at the given `NSIndexPath`. This subscript indexer is typically used for `ListMonitor`s created with `monitorSectionedList(_:)`.
    
    - parameter indexPath: the `NSIndexPath` for the object. Using an `indexPath` with an invalid range will throw an exception.
    - returns: the `NSManagedObject` at the specified index path
    */
    public subscript(indexPath: NSIndexPath) -> T {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return self.fetchedResultsController.objectAtIndexPath(indexPath) as! T
    }
    
    /**
    Returns the object at the given `NSIndexPath`, or `nil` if out of bounds. This subscript indexer is typically used for `ListMonitor`s created with `monitorSectionedList(_:)`.
    
    - parameter indexPath: the `NSIndexPath` for the object. Using an `indexPath` with an invalid range will return `nil`.
    - returns: the `NSManagedObject` at the specified index path, or `nil` if out of bounds
    */
    public subscript(safeIndexPath indexPath: NSIndexPath) -> T? {
        
        return self[
            safeSectionIndex: indexPath.indexAtPosition(0),
            safeItemIndex: indexPath.indexAtPosition(1)
        ]
    }
    
    /**
    Checks if the `ListMonitor` has at least one object in any section.
    
    - returns: `true` if at least one object in any section exists, `false` otherwise
    */
    @warn_unused_result
    public func hasObjects() -> Bool {
        
        return self.numberOfObjects() > 0
    }
    
    /**
    Checks if the `ListMonitor` has at least one object the specified section.
    
    - parameter section: the section index. Using an index outside the valid range will return `false`.
    - returns: `true` if at least one object in the specified section exists, `false` otherwise
    */
    @warn_unused_result
    public func hasObjectsInSection(section: Int) -> Bool {
        
        return self.numberOfObjectsInSection(safeSectionIndex: section) > 0
    }
    
    /**
    Returns all objects in all sections
    
    - returns: all objects in all sections
    */
    @warn_unused_result
    public func objectsInAllSections() -> [T] {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return (self.fetchedResultsController.fetchedObjects as? [T]) ?? []
    }
    
    /**
    Returns all objects in the specified section
    
    - parameter section: the section index. Using an index outside the valid range will throw an exception.
    - returns: all objects in the specified section
    */
    @warn_unused_result
    public func objectsInSection(section: Int) -> [T] {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return (self.fetchedResultsController.sections?[section].objects as? [T]) ?? []
    }
    
    /**
    Returns all objects in the specified section, or `nil` if out of bounds.
    
    - parameter section: the section index. Using an index outside the valid range will return `nil`.
    - returns: all objects in the specified section
    */
    @warn_unused_result
    public func objectsInSection(safeSectionIndex section: Int) -> [T]? {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return (self.fetchedResultsController.sections?[section].objects as? [T]) ?? []
    }
    
    /**
    Returns the number of sections
    
    - returns: the number of sections
    */
    @warn_unused_result
    public func numberOfSections() -> Int {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    /**
    Returns the number of objects in all sections
    
    - returns: the number of objects in all sections
    */
    @warn_unused_result
    public func numberOfObjects() -> Int {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return self.fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    /**
    Returns the number of objects in the specified section
    
    - parameter section: the section index. Using an index outside the valid range will throw an exception.
    - returns: the number of objects in the specified section
    */
    @warn_unused_result
    public func numberOfObjectsInSection(section: Int) -> Int {
        
        return self.sectionInfoAtIndex(section).numberOfObjects
    }
    
    /**
    Returns the number of objects in the specified section, or `nil` if out of bounds.
    
    - parameter section: the section index. Using an index outside the valid range will return `nil`.
    - returns: the number of objects in the specified section
    */
    @warn_unused_result
    public func numberOfObjectsInSection(safeSectionIndex section: Int) -> Int? {
        
        return self.sectionInfoAtIndex(safeSectionIndex: section)?.numberOfObjects
    }
    
    /**
    Returns the `NSFetchedResultsSectionInfo` for the specified section
    
    - parameter section: the section index. Using an index outside the valid range will throw an exception.
    - returns: the `NSFetchedResultsSectionInfo` for the specified section
    */
    @warn_unused_result
    public func sectionInfoAtIndex(section: Int) -> NSFetchedResultsSectionInfo {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return self.fetchedResultsController.sections![section]
    }
    
    /**
    Returns the `NSFetchedResultsSectionInfo` for the specified section, or `nil` if out of bounds.
    
    - parameter section: the section index. Using an index outside the valid range will return `nil`.
    - returns: the `NSFetchedResultsSectionInfo` for the specified section, or `nil` if the section index is out of bounds.
    */
    @warn_unused_result
    public func sectionInfoAtIndex(safeSectionIndex section: Int) -> NSFetchedResultsSectionInfo? {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        guard let sections = self.fetchedResultsController.sections
            where section < sections.count else {
                
                return nil
        }
        
        return sections[section]
    }
    
    /**
    Returns the index of the `NSManagedObject` if it exists in the `ListMonitor`'s fetched objects, or `nil` if not found.
    
    - parameter object: the `NSManagedObject` to search the index of
    - returns: the index of the `NSManagedObject` if it exists in the `ListMonitor`'s fetched objects, or `nil` if not found.
    */
    @warn_unused_result
    public func indexOf(object: T) -> Int? {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return (self.fetchedResultsController.fetchedObjects as? [T] ?? []).indexOf(object)
    }
    
    /**
    Returns the `NSIndexPath` of the `NSManagedObject` if it exists in the `ListMonitor`'s fetched objects, or `nil` if not found.
    
    - parameter object: the `NSManagedObject` to search the index of
    - returns: the `NSIndexPath` of the `NSManagedObject` if it exists in the `ListMonitor`'s fetched objects, or `nil` if not found.
    */
    @warn_unused_result
    public func indexPathOf(object: T) -> NSIndexPath? {
        
        CoreStore.assert(
            !self.isPendingRefetch || NSThread.isMainThread(),
            "Attempted to access a \(typeName(self)) outside the main thread while a refetch is in progress."
        )
        
        return self.fetchedResultsController.indexPathForObject(object)
    }
    
    
    // MARK: Public (Observers)
    
    /**
    Registers a `ListObserver` to be notified when changes to the receiver's list occur.
    
    To prevent retain-cycles, `ListMonitor` only keeps `weak` references to its observers.
    
    For thread safety, this method needs to be called from the main thread. An assertion failure will occur (on debug builds only) if called from any thread other than the main thread.
    
    Calling `addObserver(_:)` multiple times on the same observer is safe, as `ListMonitor` unregisters previous notifications to the observer before re-registering them.
    
    - parameter observer: a `ListObserver` to send change notifications to
    */
    public func addObserver<U: ListObserver where U.ListEntityType == T>(observer: U) {
        
        CoreStore.assert(
            NSThread.isMainThread(),
            "Attempted to add an observer of type \(typeName(observer)) outside the main thread."
        )
        
        self.removeObserver(observer)
        
        self.registerChangeNotification(
            &self.willChangeListKey,
            name: ListMonitorWillChangeListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorWillChange(monitor)
            }
        )
        self.registerChangeNotification(
            &self.didChangeListKey,
            name: ListMonitorDidChangeListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorDidChange(monitor)
            }
        )
        self.registerChangeNotification(
            &self.willRefetchListKey,
            name: ListMonitorWillRefetchListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorWillRefetch(monitor)
            }
        )
        self.registerChangeNotification(
            &self.didRefetchListKey,
            name: ListMonitorDidRefetchListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorDidRefetch(monitor)
            }
        )
    }
    
    /**
    Registers a `ListObjectObserver` to be notified when changes to the receiver's list occur.
    
    To prevent retain-cycles, `ListMonitor` only keeps `weak` references to its observers.
    
    For thread safety, this method needs to be called from the main thread. An assertion failure will occur (on debug builds only) if called from any thread other than the main thread.
    
    Calling `addObserver(_:)` multiple times on the same observer is safe, as `ListMonitor` unregisters previous notifications to the observer before re-registering them.
    
    - parameter observer: a `ListObjectObserver` to send change notifications to
    */
    public func addObserver<U: ListObjectObserver where U.ListEntityType == T>(observer: U) {
        
        CoreStore.assert(
            NSThread.isMainThread(),
            "Attempted to add an observer of type \(typeName(observer)) outside the main thread."
        )
        
        self.removeObserver(observer)
        
        self.registerChangeNotification(
            &self.willChangeListKey,
            name: ListMonitorWillChangeListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorWillChange(monitor)
            }
        )
        self.registerChangeNotification(
            &self.didChangeListKey,
            name: ListMonitorDidChangeListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorDidChange(monitor)
            }
        )
        self.registerChangeNotification(
            &self.willRefetchListKey,
            name: ListMonitorWillRefetchListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorWillRefetch(monitor)
            }
        )
        self.registerChangeNotification(
            &self.didRefetchListKey,
            name: ListMonitorDidRefetchListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorDidRefetch(monitor)
            }
        )
        
        self.registerObjectNotification(
            &self.didInsertObjectKey,
            name: ListMonitorDidInsertObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didInsertObject: object,
                    toIndexPath: newIndexPath!
                )
            }
        )
        self.registerObjectNotification(
            &self.didDeleteObjectKey,
            name: ListMonitorDidDeleteObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didDeleteObject: object,
                    fromIndexPath: indexPath!
                )
            }
        )
        self.registerObjectNotification(
            &self.didUpdateObjectKey,
            name: ListMonitorDidUpdateObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didUpdateObject: object,
                    atIndexPath: indexPath!
                )
            }
        )
        self.registerObjectNotification(
            &self.didMoveObjectKey,
            name: ListMonitorDidMoveObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didMoveObject: object,
                    fromIndexPath: indexPath!,
                    toIndexPath: newIndexPath!
                )
            }
        )
    }
    
    /**
    Registers a `ListSectionObserver` to be notified when changes to the receiver's list occur.
    
    To prevent retain-cycles, `ListMonitor` only keeps `weak` references to its observers.
    
    For thread safety, this method needs to be called from the main thread. An assertion failure will occur (on debug builds only) if called from any thread other than the main thread.
    
    Calling `addObserver(_:)` multiple times on the same observer is safe, as `ListMonitor` unregisters previous notifications to the observer before re-registering them.
    
    - parameter observer: a `ListSectionObserver` to send change notifications to
    */
    public func addObserver<U: ListSectionObserver where U.ListEntityType == T>(observer: U) {
        
        CoreStore.assert(
            NSThread.isMainThread(),
            "Attempted to add an observer of type \(typeName(observer)) outside the main thread."
        )
        
        self.removeObserver(observer)
        
        self.registerChangeNotification(
            &self.willChangeListKey,
            name: ListMonitorWillChangeListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorWillChange(monitor)
            }
        )
        self.registerChangeNotification(
            &self.didChangeListKey,
            name: ListMonitorDidChangeListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorDidChange(monitor)
            }
        )
        self.registerChangeNotification(
            &self.willRefetchListKey,
            name: ListMonitorWillRefetchListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorWillRefetch(monitor)
            }
        )
        self.registerChangeNotification(
            &self.didRefetchListKey,
            name: ListMonitorDidRefetchListNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitorDidRefetch(monitor)
            }
        )
        
        self.registerObjectNotification(
            &self.didInsertObjectKey,
            name: ListMonitorDidInsertObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didInsertObject: object,
                    toIndexPath: newIndexPath!
                )
            }
        )
        self.registerObjectNotification(
            &self.didDeleteObjectKey,
            name: ListMonitorDidDeleteObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                 
                    return
                }
                observer.listMonitor(
                    monitor,
                    didDeleteObject: object,
                    fromIndexPath: indexPath!
                )
            }
        )
        self.registerObjectNotification(
            &self.didUpdateObjectKey,
            name: ListMonitorDidUpdateObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didUpdateObject: object,
                    atIndexPath: indexPath!
                )
            }
        )
        self.registerObjectNotification(
            &self.didMoveObjectKey,
            name: ListMonitorDidMoveObjectNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, object, indexPath, newIndexPath) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didMoveObject: object,
                    fromIndexPath: indexPath!,
                    toIndexPath: newIndexPath!
                )
            }
        )
        
        self.registerSectionNotification(
            &self.didInsertSectionKey,
            name: ListMonitorDidInsertSectionNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, sectionInfo, sectionIndex) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didInsertSection: sectionInfo,
                    toSectionIndex: sectionIndex
                )
            }
        )
        self.registerSectionNotification(
            &self.didDeleteSectionKey,
            name: ListMonitorDidDeleteSectionNotification,
            toObserver: observer,
            callback: { [weak observer] (monitor, sectionInfo, sectionIndex) -> Void in
                
                guard let observer = observer else {
                    
                    return
                }
                observer.listMonitor(
                    monitor,
                    didDeleteSection: sectionInfo,
                    fromSectionIndex: sectionIndex
                )
            }
        )
    }
    
    /**
    Unregisters a `ListObserver` from receiving notifications for changes to the receiver's list.
    
    For thread safety, this method needs to be called from the main thread. An assertion failure will occur (on debug builds only) if called from any thread other than the main thread.
    
    - parameter observer: a `ListObserver` to unregister notifications to
    */
    public func removeObserver<U: ListObserver where U.ListEntityType == T>(observer: U) {
        
        CoreStore.assert(
            NSThread.isMainThread(),
            "Attempted to remove an observer of type \(typeName(observer)) outside the main thread."
        )
        
        let nilValue: AnyObject? = nil
        setAssociatedRetainedObject(nilValue, forKey: &self.willChangeListKey, inObject: observer)
        setAssociatedRetainedObject(nilValue, forKey: &self.didChangeListKey, inObject: observer)
        setAssociatedRetainedObject(nilValue, forKey: &self.willRefetchListKey, inObject: observer)
        setAssociatedRetainedObject(nilValue, forKey: &self.didRefetchListKey, inObject: observer)
        
        setAssociatedRetainedObject(nilValue, forKey: &self.didInsertObjectKey, inObject: observer)
        setAssociatedRetainedObject(nilValue, forKey: &self.didDeleteObjectKey, inObject: observer)
        setAssociatedRetainedObject(nilValue, forKey: &self.didUpdateObjectKey, inObject: observer)
        setAssociatedRetainedObject(nilValue, forKey: &self.didMoveObjectKey, inObject: observer)
        
        setAssociatedRetainedObject(nilValue, forKey: &self.didInsertSectionKey, inObject: observer)
        setAssociatedRetainedObject(nilValue, forKey: &self.didDeleteSectionKey, inObject: observer)
    }
    
    
    // MARK: Public (Refetching)
    
    /**
    Returns `true` if a call to `refetch(...)` was made to the `ListMonitor` and is currently waiting for the fetching to complete. Returns `false` otherwise.
    */
    private(set) public var isPendingRefetch = false
    
    /**
    Asks the `ListMonitor` to refetch its objects using the specified series of `FetchClause`s. Note that this method does not execute the fetch immediately; the actual fetching will happen after the `NSFetchedResultsController`'s last `controllerDidChangeContent(_:)` notification completes.
    
    `refetch(...)` broadcasts `listMonitorWillRefetch(...)` to its observers immediately, and then `listMonitorDidRefetch(...)` after the new fetch request completes.
    
    - parameter fetchClauses: a series of `FetchClause` instances for fetching the object list. Accepts `Where`, `OrderBy`, and `Tweak` clauses. Note that only specified clauses will be changed; unspecified clauses will use previous values.
    */
    public func refetch(fetchClauses: FetchClause...) {
        
        self.refetch(fetchClauses)
    }
    
    /**
    Asks the `ListMonitor` to refetch its objects using the specified series of `FetchClause`s. Note that this method does not execute the fetch immediately; the actual fetching will happen after the `NSFetchedResultsController`'s last `controllerDidChangeContent(_:)` notification completes.
    
    `refetch(...)` broadcasts `listMonitorWillRefetch(...)` to its observers immediately, and then `listMonitorDidRefetch(...)` after the new fetch request completes.
    
    - parameter fetchClauses: a series of `FetchClause` instances for fetching the object list. Accepts `Where`, `OrderBy`, and `Tweak` clauses. Note that only specified clauses will be changed; unspecified clauses will use previous values.
    */
    public func refetch(fetchClauses: [FetchClause]) {
        
        CoreStore.assert(
            NSThread.isMainThread(),
            "Attempted to refetch a \(typeName(self)) outside the main thread."
        )
        
        self.isPendingRefetch = true
        
        NSNotificationCenter.defaultCenter().postNotificationName(
            ListMonitorWillRefetchListNotification,
            object: self
        )
        
        self.taskGroup.notify(.Main) { [weak self] () -> Void in
            
            guard let strongSelf = self else {
                
                return
            }
            
            strongSelf.fetchedResultsControllerDelegate.enabled = false
            
            let fetchRequest = strongSelf.fetchedResultsController.fetchRequest
            for clause in fetchClauses {
                
                clause.applyToFetchRequest(fetchRequest)
            }
            
            strongSelf.parentStack?.childTransactionQueue.async {
                
                guard let strongSelf = self else {
                    
                    return
                }
                
                try! strongSelf.fetchedResultsController.performFetch()
                
                GCDQueue.Main.async { () -> Void in
                    
                    guard let strongSelf = self else {
                        
                        return
                    }
                    
                    strongSelf.fetchedResultsControllerDelegate.enabled = true
                    strongSelf.isPendingRefetch = false
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(
                        ListMonitorDidRefetchListNotification,
                        object: strongSelf
                    )
                }
            }
        }
    }
    
    
    // MARK: Internal
    
    internal convenience init(dataStack: DataStack, from: From<T>, sectionBy: SectionBy?, fetchClauses: [FetchClause]) {
     
        self.init(
            dataStack: dataStack,
            from: from,
            sectionBy: sectionBy,
            fetchClauses: fetchClauses,
            prepareFetch: { _, performFetch in performFetch() }
        )
    }
    
    internal convenience init(dataStack: DataStack, from: From<T>, sectionBy: SectionBy?, fetchClauses: [FetchClause], createAsynchronously: (ListMonitor<T>) -> Void) {
        
        self.init(
            dataStack: dataStack,
            from: from,
            sectionBy: sectionBy,
            fetchClauses: fetchClauses,
            prepareFetch: { listMonitor, performFetch in
                
                dataStack.childTransactionQueue.async {
                    
                    performFetch()
                    GCDQueue.Main.async {
                        
                        createAsynchronously(listMonitor)
                    }
                }
            }
        )
    }
    
    private init(dataStack: DataStack, from: From<T>, sectionBy: SectionBy?, fetchClauses: [FetchClause], prepareFetch: (ListMonitor<T>, () -> Void) -> Void) {
        
        let fetchRequest = NSFetchRequest()
        fetchRequest.fetchLimit = 0
        fetchRequest.resultType = .ManagedObjectResultType
        fetchRequest.fetchBatchSize = 20
        fetchRequest.includesPendingChanges = false
        fetchRequest.shouldRefreshRefetchedObjects = true
        
        let fetchedResultsController = NSFetchedResultsController(
            dataStack: dataStack,
            fetchRequest: fetchRequest,
            from: from,
            sectionBy: sectionBy,
            fetchClauses: fetchClauses
        )
        
        let fetchedResultsControllerDelegate = FetchedResultsControllerDelegate()
        
        self.fetchedResultsController = fetchedResultsController
        self.fetchedResultsControllerDelegate = fetchedResultsControllerDelegate
        self.parentStack = dataStack
        
        if let sectionIndexTransformer = sectionBy?.sectionIndexTransformer {
            
            self.sectionIndexTransformer = sectionIndexTransformer
        }
        else {
            
            self.sectionIndexTransformer = { $0 }
        }
        
        fetchedResultsControllerDelegate.handler = self
        fetchedResultsControllerDelegate.fetchedResultsController = fetchedResultsController
        
        prepareFetch(self, { try! fetchedResultsController.performFetch() })
    }
    
    deinit {
        
        self.fetchedResultsControllerDelegate.fetchedResultsController = nil
    }
    
    
    // MARK: Private
    
    private let fetchedResultsController: NSFetchedResultsController
    private let fetchedResultsControllerDelegate: FetchedResultsControllerDelegate
    private let sectionIndexTransformer: (sectionName: KeyPath?) -> String?
    private let taskGroup = GCDGroup()
    private weak var parentStack: DataStack?
    
    private var willChangeListKey: Void?
    private var didChangeListKey: Void?
    private var willRefetchListKey: Void?
    private var didRefetchListKey: Void?
    
    private var didInsertObjectKey: Void?
    private var didDeleteObjectKey: Void?
    private var didUpdateObjectKey: Void?
    private var didMoveObjectKey: Void?
    
    private var didInsertSectionKey: Void?
    private var didDeleteSectionKey: Void?
    
    private func registerChangeNotification(notificationKey: UnsafePointer<Void>, name: String, toObserver observer: AnyObject, callback: (monitor: ListMonitor<T>) -> Void) {
        
        setAssociatedRetainedObject(
            NotificationObserver(
                notificationName: name,
                object: self,
                closure: { [weak self] (note) -> Void in
                    
                    guard let strongSelf = self else {
                        
                        return
                    }
                    callback(monitor: strongSelf)
                }
            ),
            forKey: notificationKey,
            inObject: observer
        )
    }
    
    private func registerObjectNotification(notificationKey: UnsafePointer<Void>, name: String, toObserver observer: AnyObject, callback: (monitor: ListMonitor<T>, object: T, indexPath: NSIndexPath?, newIndexPath: NSIndexPath?) -> Void) {
        
        setAssociatedRetainedObject(
            NotificationObserver(
                notificationName: name,
                object: self,
                closure: { [weak self] (note) -> Void in
                    
                    guard let strongSelf = self,
                        let userInfo = note.userInfo,
                        let object = userInfo[UserInfoKeyObject] as? T else {
                            
                            return
                    }
                    callback(
                        monitor: strongSelf,
                        object: object,
                        indexPath: userInfo[UserInfoKeyIndexPath] as? NSIndexPath,
                        newIndexPath: userInfo[UserInfoKeyNewIndexPath] as? NSIndexPath
                    )
                }
            ),
            forKey: notificationKey,
            inObject: observer
        )
    }
    
    private func registerSectionNotification(notificationKey: UnsafePointer<Void>, name: String, toObserver observer: AnyObject, callback: (monitor: ListMonitor<T>, sectionInfo: NSFetchedResultsSectionInfo, sectionIndex: Int) -> Void) {
        
        setAssociatedRetainedObject(
            NotificationObserver(
                notificationName: name,
                object: self,
                closure: { [weak self] (note) -> Void in
                    
                    guard let strongSelf = self,
                        let userInfo = note.userInfo,
                        let sectionInfo = userInfo[UserInfoKeySectionInfo] as? NSFetchedResultsSectionInfo,
                        let sectionIndex = (userInfo[UserInfoKeySectionIndex] as? NSNumber)?.integerValue else {
                            
                            return
                    }
                    callback(
                        monitor: strongSelf,
                        sectionInfo: sectionInfo,
                        sectionIndex: sectionIndex
                    )
                }
            ),
            forKey: notificationKey,
            inObject: observer
        )
    }
}


// MARK: - ListMonitor: Equatable

@available(OSX, unavailable)
public func ==<T: NSManagedObject>(lhs: ListMonitor<T>, rhs: ListMonitor<T>) -> Bool {
    
    return lhs === rhs
}

@available(OSX, unavailable)
extension ListMonitor: Equatable { }


// MARK: - ListMonitor: FetchedResultsControllerHandler

@available(OSX, unavailable)
extension ListMonitor: FetchedResultsControllerHandler {
    
    // MARK: FetchedResultsControllerHandler
    
    internal func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type {
            
        case .Insert:
            NSNotificationCenter.defaultCenter().postNotificationName(
                ListMonitorDidInsertObjectNotification,
                object: self,
                userInfo: [
                    UserInfoKeyObject: anObject,
                    UserInfoKeyNewIndexPath: newIndexPath!
                ]
            )
            
        case .Delete:
            NSNotificationCenter.defaultCenter().postNotificationName(
                ListMonitorDidDeleteObjectNotification,
                object: self,
                userInfo: [
                    UserInfoKeyObject: anObject,
                    UserInfoKeyIndexPath: indexPath!
                ]
            )
            
        case .Update:
            NSNotificationCenter.defaultCenter().postNotificationName(
                ListMonitorDidUpdateObjectNotification,
                object: self,
                userInfo: [
                    UserInfoKeyObject: anObject,
                    UserInfoKeyIndexPath: indexPath!
                ]
            )
            
        case .Move:
            NSNotificationCenter.defaultCenter().postNotificationName(
                ListMonitorDidMoveObjectNotification,
                object: self,
                userInfo: [
                    UserInfoKeyObject: anObject,
                    UserInfoKeyIndexPath: indexPath!,
                    UserInfoKeyNewIndexPath: newIndexPath!
                ]
            )
        }
    }
    
    internal func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
        switch type {
            
        case .Insert:
            NSNotificationCenter.defaultCenter().postNotificationName(
                ListMonitorDidInsertSectionNotification,
                object: self,
                userInfo: [
                    UserInfoKeySectionInfo: sectionInfo,
                    UserInfoKeySectionIndex: NSNumber(integer: sectionIndex)
                ]
            )
            
        case .Delete:
            NSNotificationCenter.defaultCenter().postNotificationName(
                ListMonitorDidDeleteSectionNotification,
                object: self,
                userInfo: [
                    UserInfoKeySectionInfo: sectionInfo,
                    UserInfoKeySectionIndex: NSNumber(integer: sectionIndex)
                ]
            )
            
        default:
            break
        }
    }
    
    internal func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
        self.taskGroup.enter()
        NSNotificationCenter.defaultCenter().postNotificationName(
            ListMonitorWillChangeListNotification,
            object: self
        )
    }
    
   internal func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        NSNotificationCenter.defaultCenter().postNotificationName(
            ListMonitorDidChangeListNotification,
            object: self
        )
        self.taskGroup.leave()
    }
    
   internal func controller(controller: NSFetchedResultsController, sectionIndexTitleForSectionName sectionName: String?) -> String? {
    
        return self.sectionIndexTransformer(sectionName: sectionName)
    }
}


private let ListMonitorWillChangeListNotification = "ListMonitorWillChangeListNotification"
private let ListMonitorDidChangeListNotification = "ListMonitorDidChangeListNotification"
private let ListMonitorWillRefetchListNotification = "ListMonitorWillRefetchListNotification"
private let ListMonitorDidRefetchListNotification = "ListMonitorDidRefetchListNotification"

private let ListMonitorDidInsertObjectNotification = "ListMonitorDidInsertObjectNotification"
private let ListMonitorDidDeleteObjectNotification = "ListMonitorDidDeleteObjectNotification"
private let ListMonitorDidUpdateObjectNotification = "ListMonitorDidUpdateObjectNotification"
private let ListMonitorDidMoveObjectNotification = "ListMonitorDidMoveObjectNotification"

private let ListMonitorDidInsertSectionNotification = "ListMonitorDidInsertSectionNotification"
private let ListMonitorDidDeleteSectionNotification = "ListMonitorDidDeleteSectionNotification"

private let UserInfoKeyObject = "UserInfoKeyObject"
private let UserInfoKeyIndexPath = "UserInfoKeyIndexPath"
private let UserInfoKeyNewIndexPath = "UserInfoKeyNewIndexPath"

private let UserInfoKeySectionInfo = "UserInfoKeySectionInfo"
private let UserInfoKeySectionIndex = "UserInfoKeySectionIndex"
