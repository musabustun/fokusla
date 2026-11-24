import CryptoKit
import Foundation

/// Arkadaşlık mektubunu alıcının açık anahtarıyla mühürler (HPKE: Curve25519 + HKDF-SHA256 + ChaChaPoly).
/// Mektup public veritabanında durur; içindeki tek kullanımlık davet bağlantısını yalnız alıcı açabilir.
public enum SocialMailCrypto {
    public enum Failure: Error, Sendable, Hashable { case invalidKey, invalidMessage }

    private static let suite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
    private static let encapsulatedKeyLength = 32

    public static func generatePrivateKey() -> Data {
        Curve25519.KeyAgreement.PrivateKey().rawRepresentation
    }

    public static func publicKey(forPrivateKey privateKey: Data) throws -> Data {
        try key(privateKey).publicKey.rawRepresentation
    }

    /// `mailbox` bağlama dahildir: bir mektup başka bir posta kutusuna kopyalanıp açılamaz.
    public static func seal(_ message: Data, publicKey: Data, mailbox: String) throws -> Data {
        guard let recipient = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey) else {
            throw Failure.invalidKey
        }
        var sender = try HPKE.Sender(recipientKey: recipient, ciphersuite: suite, info: info(mailbox))
        let sealed = try sender.seal(message)
        return sender.encapsulatedKey + sealed
    }

    public static func open(_ sealed: Data, privateKey: Data, mailbox: String) throws -> Data {
        let recipient = try key(privateKey)
        guard sealed.count > encapsulatedKeyLength else { throw Failure.invalidMessage }
        do {
            var opener = try HPKE.Recipient(
                privateKey: recipient, ciphersuite: suite, info: info(mailbox),
                encapsulatedKey: Data(sealed.prefix(encapsulatedKeyLength)))
            return try opener.open(Data(sealed.dropFirst(encapsulatedKeyLength)))
        } catch {
            throw Failure.invalidMessage
        }
    }

    private static func key(_ raw: Data) throws -> Curve25519.KeyAgreement.PrivateKey {
        guard let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) else {
            throw Failure.invalidKey
        }
        return key
    }

    private static func info(_ mailbox: String) -> Data { Data("fokus.mail.v1:\(mailbox)".utf8) }
}
