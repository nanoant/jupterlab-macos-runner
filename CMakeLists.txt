cmake_minimum_required(VERSION 3.10)

project(JupyterLab)

add_executable(
	${PROJECT_NAME}
	MACOSX_BUNDLE
	main.m
	)

set_target_properties(
	${PROJECT_NAME}
	PROPERTIES
	MACOSX_BUNDLE_INFO_PLIST     "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
	MACOSX_BUNDLE_ICON_FILE      "AppIcon"
	MACOSX_BUNDLE_BUNDLE_NAME    "${PROJECT_NAME}"
	MACOSX_BUNDLE_BUNDLE_VERSION "0.1"
	MACOSX_BUNDLE_COPYRIGHT      "${PROJECT_NAME} macOS Runner is licensed under the MIT License"
	MACOSX_BUNDLE_GUI_IDENTIFIER "com.nanoant.webapp.${PROJECT_NAME}"
	)

set(ICON_TARGET "${CMAKE_BINARY_DIR}/AppIcon.iconset")
set(ICON_OUTPUT "${CMAKE_BINARY_DIR}/AppIcon.icns")
set(ICON_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/AppIcon.png")

add_custom_command(OUTPUT ${ICON_OUTPUT}
	COMMAND mkdir -p ${ICON_TARGET}
	COMMAND sips -z 16 16     ${ICON_SOURCE} --out ${ICON_TARGET}/icon_16x16.png
	COMMAND sips -z 32 32     ${ICON_SOURCE} --out ${ICON_TARGET}/icon_16x16@2x.png
	COMMAND sips -z 32 32     ${ICON_SOURCE} --out ${ICON_TARGET}/icon_32x32.png
	COMMAND sips -z 64 64     ${ICON_SOURCE} --out ${ICON_TARGET}/icon_32x32@2x.png
	COMMAND sips -z 128 128   ${ICON_SOURCE} --out ${ICON_TARGET}/icon_128x128.png
	COMMAND sips -z 256 256   ${ICON_SOURCE} --out ${ICON_TARGET}/icon_128x128@2x.png
	COMMAND sips -z 256 256   ${ICON_SOURCE} --out ${ICON_TARGET}/icon_256x256.png
	COMMAND sips -z 512 512   ${ICON_SOURCE} --out ${ICON_TARGET}/icon_256x256@2x.png
	COMMAND sips -z 512 512   ${ICON_SOURCE} --out ${ICON_TARGET}/icon_512x512.png
	COMMAND sips -z 1024 1024 ${ICON_SOURCE} --out ${ICON_TARGET}/icon_512x512@2x.png
	COMMAND iconutil -c icns ${ICON_TARGET}
	WORKING_DIRECTORY ${CMAKE_BINARY_DIR})

set(BUNDLE_RESOURCES ${ICON_OUTPUT})
set_target_properties(${PROJECT_NAME} PROPERTIES RESOURCE "${BUNDLE_RESOURCES}")
target_sources(${PROJECT_NAME} PUBLIC ${BUNDLE_RESOURCES})

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AppKit -framework WebKit")
