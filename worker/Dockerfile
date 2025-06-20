# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
 
WORKDIR /source
 
# Copy everything as-is (no nested structure)
COPY . .
 
RUN dotnet restore Worker.sln
RUN dotnet publish Worker.csproj -c Release -o /app/publish
 
# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/runtime:7.0 AS runtime
 
WORKDIR /app
 
COPY --from=build /app/publish ./
 
ENTRYPOINT ["dotnet", "Worker.dll"]