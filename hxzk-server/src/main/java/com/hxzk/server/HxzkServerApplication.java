package com.hxzk.server;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@MapperScan("com.hxzk.server.modules.**.mapper")
public class HxzkServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(HxzkServerApplication.class, args);
    }
}
