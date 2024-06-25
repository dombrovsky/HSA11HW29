using Amazon;
using Amazon.Lambda.Core;
using Amazon.Lambda.S3Events;
using Amazon.S3;
using Amazon.S3.Model;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats;

// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace LambdaImageConverter;

public class Function
{
    private static readonly string BmpBucket = Environment.GetEnvironmentVariable("BMP_BUCKET");
    private static readonly string GifBucket = Environment.GetEnvironmentVariable("GIF_BUCKET");
    private static readonly string PngBucket = Environment.GetEnvironmentVariable("PNG_BUCKET");

    private readonly IAmazonS3 _s3Client = new AmazonS3Client(RegionEndpoint.USWest2);

    public async Task FunctionHandler(S3Event evnt, ILambdaContext context)
    {
        context.Logger.LogInformation($"{nameof(FunctionHandler)}: {evnt}");

        var s3Event = evnt.Records?[0].S3;
        if (s3Event == null) return;

        var bucketName = s3Event.Bucket.Name;
        var objectKey = s3Event.Object.Key;

        context.Logger.LogInformation($"{bucketName}: {objectKey}");

        try
        {
            var response = await _s3Client.GetObjectAsync(bucketName, objectKey);
            context.Logger.LogInformation($"Got object: {response.ContentLength}");
            using (var responseStream = response.ResponseStream)
            using (var image = Image.Load(responseStream))
            {
                await ConvertAndUploadImage(image, objectKey, "bmp", BmpBucket, context);
                await ConvertAndUploadImage(image, objectKey, "gif", GifBucket, context);
                await ConvertAndUploadImage(image, objectKey, "png", PngBucket, context);
            }
        }
        catch (Exception e)
        {
            context.Logger.LogError($"Error processing {objectKey} from {bucketName}: {e.Message}");
            throw;
        }
    }

    private async Task ConvertAndUploadImage(Image image, string originalKey, string format, string destinationBucket, ILambdaContext context)
    {
        context.Logger.LogInformation($"Converting {format}");

        var newKey = originalKey.Replace(".jpg", $".{format}");
        using (var memoryStream = new MemoryStream())
        {
            image.Save(memoryStream, GetEncoder(format));
            memoryStream.Seek(0, SeekOrigin.Begin);

            var putRequest = new PutObjectRequest
            {
                BucketName = destinationBucket,
                Key = newKey,
                InputStream = memoryStream,
                ContentType = $"image/{format}"
            };

            context.Logger.LogInformation($"Uploading to {destinationBucket}");
            await _s3Client.PutObjectAsync(putRequest);
        }
    }

    private IImageEncoder GetEncoder(string format)
    {
        return format switch
        {
            "bmp" => new SixLabors.ImageSharp.Formats.Bmp.BmpEncoder(),
            "gif" => new SixLabors.ImageSharp.Formats.Gif.GifEncoder(),
            "png" => new SixLabors.ImageSharp.Formats.Png.PngEncoder(),
            _ => throw new NotSupportedException($"Format {format} is not supported")
        };
    }
}
