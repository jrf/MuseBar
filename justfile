# Default recipe
default: install

product := "MuseBar"
app_dir := "build/" + product + ".app/Contents"

# Build release and package as .app
build:
    swift build -c release
    mkdir -p {{app_dir}}/MacOS
    mkdir -p {{app_dir}}/Resources
    cp .build/release/{{product}} {{app_dir}}/MacOS/
    cp Resources/Info.plist {{app_dir}}/
    cp Resources/AppIcon.icns {{app_dir}}/Resources/
    codesign --force --sign - build/{{product}}.app
    @echo "Built {{product}}.app in build/"

# Build and run (kills old instance first)
run: build
    -pkill -x {{product}}
    ./build/{{product}}.app/Contents/MacOS/{{product}}

# Build debug
debug:
    swift build

# Install to /Applications
install: build
    -pkill -x {{product}}
    rm -rf /Applications/{{product}}.app
    cp -r build/{{product}}.app /Applications/
    open /Applications/{{product}}.app
    @echo "Installed to /Applications/{{product}}.app"

# Clean build artifacts
clean:
    rm -rf .build build
