import Foundation

struct FieldError: Codable, Equatable, Sendable {
    let field: String
    let message: String
}

enum AppError: Error, Equatable, LocalizedError {
    case unauthenticated
    case forbidden(code: String?, message: String)
    case validation([FieldError])
    case business(code: String, message: String)
    case rateLimited(retryAfter: Int?)
    case unavailable(message: String)
    case network(message: String)
    case cancelled
    case staleSession
    case invalidResponse(message: String)
    case unknown(message: String)

    var code: String? {
        switch self {
        case .business(let code, _):
            return code
        case .forbidden(let code, _):
            return code
        default:
            return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "登录已失效，请重新登录"
        case .forbidden(_, let message):
            return message.isEmpty ? "没有权限执行此操作" : message
        case .validation(let fields):
            let text = fields.map(\.message).joined(separator: "；")
            return text.isEmpty ? "输入内容有误" : text
        case .business(_, let message):
            return message.isEmpty ? "操作未完成，请重试" : message
        case .rateLimited(let retryAfter):
            if let retryAfter, retryAfter > 0 {
                return "请求过于频繁，请 \(retryAfter) 秒后重试"
            }
            return "请求过于频繁，请稍后重试"
        case .unavailable(let message):
            return message.isEmpty ? "服务暂时不可用，请稍后重试" : message
        case .network(let message):
            return message.isEmpty ? "网络连接失败，请检查网络后重试" : message
        case .cancelled:
            return "请求已取消"
        case .staleSession:
            return "账号或会话已变化，请重试"
        case .invalidResponse(let message):
            return message.isEmpty ? "服务响应异常，请稍后重试" : message
        case .unknown(let message):
            return message.isEmpty ? "操作失败，请重试" : message
        }
    }
}
