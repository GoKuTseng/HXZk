package com.hxzk.server.common;

import java.io.Serializable;

/**
 * 统一返回体。code=0 成功（与泛微接口契约一致），非 0 为业务/系统错误。
 */
public class Result<T> implements Serializable {

    private static final long serialVersionUID = 1L;

    public static final int CODE_OK = 0;
    public static final int CODE_BIZ_ERROR = 1;
    public static final int CODE_SYSTEM_ERROR = 500;

    private int code;
    private String msg;
    private T data;

    public Result() {
    }

    public Result(int code, String msg, T data) {
        this.code = code;
        this.msg = msg;
        this.data = data;
    }

    public static <T> Result<T> ok() {
        return new Result<>(CODE_OK, "ok", null);
    }

    public static <T> Result<T> ok(T data) {
        return new Result<>(CODE_OK, "ok", data);
    }

    public static <T> Result<T> fail(int code, String msg) {
        return new Result<>(code, msg, null);
    }

    public static <T> Result<T> fail(String msg) {
        return new Result<>(CODE_BIZ_ERROR, msg, null);
    }

    public int getCode() {
        return code;
    }

    public void setCode(int code) {
        this.code = code;
    }

    public String getMsg() {
        return msg;
    }

    public void setMsg(String msg) {
        this.msg = msg;
    }

    public T getData() {
        return data;
    }

    public void setData(T data) {
        this.data = data;
    }
}
