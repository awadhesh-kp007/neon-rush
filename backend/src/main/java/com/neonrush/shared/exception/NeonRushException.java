package com.neonrush.shared.exception;

import org.springframework.http.HttpStatus;

/**
 * Base checked exception for NEON RUSH business-logic errors.
 *
 * <p>Throw instead of raw RuntimeException so the global handler can
 * map to the correct HTTP status and structured response body.
 */
public class NeonRushException extends RuntimeException {

    private final HttpStatus status;

    public NeonRushException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public NeonRushException(HttpStatus status, String message, Throwable cause) {
        super(message, cause);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
