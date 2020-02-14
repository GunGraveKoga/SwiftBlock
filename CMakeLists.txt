cmake_minimum_required(VERSION 3.16)

project(SwiftBlock LANGUAGES Swift)

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

add_library(SwiftBlock SHARED 
    Sources/SwiftBlock/Block.swift
    Sources/SwiftBlock/BlockSignature.swift)