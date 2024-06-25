# HSA11HW29

```
dotnet tool install -g Amazon.Lambda.Tools
cd LambdaImageConverter
dotnet build -c Release
dotnet lambda package -c Release -o function.zip
cd ..
terraform init
terraform apply
```