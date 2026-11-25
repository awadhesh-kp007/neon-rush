package com.neonrush.shared.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.Instant;

/**
 * Unified API response envelope for all endpoints.
 *
 * <p>All REST controllers return this type. The {@code data} field
 * contains the domain-specific payload. {@code error} is null on success;
 * {@code data} is null on error.
 *
 * @param <T> The type of the response payload.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(
        boolean success,
        String message,
        T data,
        ApiError error,
        Instant timestamp
) {

    /** Success with data payload. */
    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, null, data, null, Instant.now());
    }

    /** Success with message + data. */
    public static <T> ApiResponse<T> success(String message, T data) {
        return new ApiResponse<>(true, message, data, null, Instant.now());
    }

    /** Backward-compat aliases. */
    public static <T> ApiResponse<T> ok(T data) { return success(data); }
    public static <T> ApiResponse<T> ok(String message, T data) { return success(message, data); }

    /** Error with HTTP status code and message. */
    public static <T> ApiResponse<T> error(int statusCode, String message) {
        return new ApiResponse<>(false, null, null,
                new ApiError(String.valueOf(statusCode), message), Instant.now());
    }

    /** Error with structured ApiError. */
    public static <T> ApiResponse<T> fail(ApiError error) {
        return new ApiResponse<>(false, null, null, error, Instant.now());
    }

    public static <T> ApiResponse<T> fail(String code, String message) {
        return new ApiResponse<>(false, null, null, new ApiError(code, message), Instant.now());
    }

    /**
     * Structured error detail embedded in failed responses.
     */
    public record ApiError(String code, String message) {}
}
