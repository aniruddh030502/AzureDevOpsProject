# syntax=docker/dockerfile:1.4

# Base build image
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build

# Optional cross-arch args (ignored unless BuildKit is used)
ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM

RUN echo "Building on $BUILDPLATFORM for $TARGETPLATFORM"

WORKDIR /source

# Copy and restore
COPY *.csproj .
RUN dotnet restore

# Copy everything else and publish
COPY . .
RUN dotnet publish -c Release -o /app --no-restore --self-contained false

# Runtime image
FROM mcr.microsoft.com/dotnet/runtime:7.0
WORKDIR /app
COPY --from=build /app .

# Entry point
ENTRYPOINT ["dotnet", "Worker.dll"]
