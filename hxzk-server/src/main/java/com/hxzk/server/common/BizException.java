package com.hxzk.server.common;

/**
 * 业务异常：抛出后由 GlobalExceptionHandler 转为统一返回体。
 */
public class BizException extends RuntimeException {

    private static final long serialVersionUID = 1L;

    private final int code;

    public BizException(String message) {
        this(Result.CODE_BIZ_ERROR, message);
    }

    public BizException(int code, String message) {
        super(message);
        this.code = code;
    }

    public int getCode() {
        return code;
    }
}
