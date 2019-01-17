import Core
import Vapor
import Foundation

public protocol NetworkDriver: Service {
    var pathBuilder: PathBuilder { get set }

    @discardableResult
    func upload(entity: inout FileEntity, on container: Container) throws -> Future<String>
    func get(path: String, on container: Container) throws -> Future<[UInt8]>
    func delete(path: String, on container: Container) throws -> Future<Void>
}

public final class S3Driver: NetworkDriver {
    enum Error: Swift.Error {
        case nilFileUpload
        case missingFileExtensionAndType
        case pathMissingForwardSlash
    }

    public var pathBuilder: PathBuilder
    var s3: S3

    public init(
        bucket: String,
        host: String = "s3.amazonaws.com",
        accessKey: String,
        secretKey: String,
        region: String = "eu-west-1",
        pathTemplate: String = ""
    ) throws {
        self.pathBuilder = try ConfigurablePathBuilder(template: pathTemplate)
        self.s3 = S3(
            host: "\(bucket).\(host)",
            accessKey: accessKey,
            secretKey: secretKey,
            region: region
        )
    }

    @discardableResult
    public func upload(entity: inout FileEntity, on container: Container) throws -> Future<String> {
        guard let bytes = entity.bytes else {
            throw Error.nilFileUpload
        }

        entity.sanitize()

        if entity.fileExtension == nil {
            guard entity.loadFileExtensionFromMime() else {
                throw Error.missingFileExtensionAndType
            }
        }

        if entity.mime == nil {
            guard entity.loadMimeFromFileExtension() else {
                throw Error.missingFileExtensionAndType
            }
        }

        let path = try pathBuilder.build(entity: entity)

        guard path.hasPrefix("/") else {
            print("The S3 driver requires your path to begin with `/`")
            print("Please check `template` in `storage.json`.")
            throw Error.pathMissingForwardSlash
        }

        return try s3.upload(
            bytes: Data(bytes),
            path: path,
            access: .publicRead,
            on: container
        ).map { _ in
            return path
        }
    }

    public func get(path: String, on container: Container) throws -> Future<[UInt8]> {
        return container.future([])
    }

    public func delete(path: String, on container: Container) throws -> Future<Void> {
        return container.future()
    }
}
