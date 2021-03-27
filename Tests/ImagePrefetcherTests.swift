// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Nuke

class ImagePreheaterTests: XCTestCase {
    var pipeline: MockImagePipeline!
    var preheater: ImagePrefetcher!

    override func setUp() {
        super.setUp()

        pipeline = MockImagePipeline {
            $0.imageCache = nil
        }
        preheater = ImagePrefetcher(pipeline: pipeline)
    }

    // MARK: - Starting Preheating

    func testStartPreheatingWithTheSameRequests() {
        pipeline.operationQueue.isSuspended = true

        // When starting preheating for the same requests (same cacheKey, loadKey).
        expect(pipeline.operationQueue).toFinishWithEnqueuedOperationCount(1)

        let request = Test.request
        preheater.startPrefetching(with: [request])
        preheater.startPrefetching(with: [request])

        wait()
    }

    func testStartPreheatingWithDifferentProcessors() {
        pipeline.operationQueue.isSuspended = true

        // When starting preheating for the requests with the same URL (same loadKey)
        // but different processors (different cacheKey).
        expect(pipeline.operationQueue).toFinishWithEnqueuedOperationCount(2)

        preheater.startPrefetching(with: [ImageRequest(url: Test.url, processors: [ImageProcessors.Anonymous(id: "1", { $0 })])])
        preheater.startPrefetching(with: [ImageRequest(url: Test.url, processors: [ImageProcessors.Anonymous(id: "2", { $0 })])])

        wait()
    }

    func testStartPreheatingSameProcessorsDifferentURLRequests() {
        pipeline.operationQueue.isSuspended = true

        // When starting preheating for the requests with the same URL, but
        // different URL requests (different loadKey) but the same processors
        // (same cacheKey).
        expect(pipeline.operationQueue).toFinishWithEnqueuedOperationCount(2)

        preheater.startPrefetching(with: [ImageRequest(urlRequest: URLRequest(url: Test.url, cachePolicy: .returnCacheDataDontLoad, timeoutInterval: 100))])
        preheater.startPrefetching(with: [ImageRequest(urlRequest: URLRequest(url: Test.url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 100))])

        wait()
    }

    func testStartingPreheatingWithURLS() {
        pipeline.operationQueue.isSuspended = true

        expect(pipeline.operationQueue).toFinishWithEnqueuedOperationCount(1)

        preheater.startPrefetching(with: [Test.url])

        wait()
    }

    // MARK: - Stoping Preheating

    func testThatPreheatingRequestsAreStopped() {
        pipeline.operationQueue.isSuspended = true

        let request = Test.request
        _ = expectNotification(MockImagePipeline.DidStartTask, object: pipeline)
        preheater.startPrefetching(with: [request])
        wait()

        _ = expectNotification(MockImagePipeline.DidCancelTask, object: pipeline)
        preheater.stopPrefetching(with: [request])
        wait()
    }

    func testThatEquaivalentRequestsAreStoppedWithSingleStopCall() {
        pipeline.operationQueue.isSuspended = true

        let request = Test.request
        _ = expectNotification(MockImagePipeline.DidStartTask, object: pipeline)
        preheater.startPrefetching(with: [request, request])
        wait()

        _ = expectNotification(MockImagePipeline.DidCancelTask, object: pipeline)
        preheater.stopPrefetching(with: [request])

        wait { _ in
            XCTAssertEqual(self.pipeline.createdTaskCount, 1, "")
        }
    }

    func testThatAllPreheatingRequestsAreStopped() {
        pipeline.operationQueue.isSuspended = true

        let request = Test.request
        _ = expectNotification(MockImagePipeline.DidStartTask, object: pipeline)
        preheater.startPrefetching(with: [request])
        wait()

        _ = expectNotification(MockImagePipeline.DidCancelTask, object: pipeline)
        preheater.stopPrefetching()
        wait()
    }

    func testThatAllPreheatingRequestsAreStoppedWhenPreheaterIsDeallocated() {
        pipeline.operationQueue.isSuspended = true

        let request = Test.request
        _ = expectNotification(MockImagePipeline.DidStartTask, object: pipeline)
        preheater.startPrefetching(with: [request])
        wait()

        _ = expectNotification(MockImagePipeline.DidCancelTask, object: pipeline)
        autoreleasepool {
            preheater = nil
        }
        wait()
    }

    func testIntegration() {
        // GIVEN
        let pipeline = ImagePipeline()
        let preheater = ImagePrefetcher(pipeline: pipeline, destination: .memoryCache, maxConcurrentRequestCount: 2)

        // WHEN
        preheater.queue.isSuspended = true
        expect(preheater.queue).toFinishWithEnqueuedOperationCount(1)
        let url = Test.url(forResource: "fixture", extension: "jpeg")
        preheater.startPrefetching(with: [url])
        wait()

        // THEN
        XCTAssertNotNil(pipeline.configuration.imageCache?[url])
    }
}