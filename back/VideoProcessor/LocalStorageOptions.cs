namespace VideoProcessor;

public class LocalStorageOptions
{
    public string RootPath { get; set; } = Path.Combine(AppContext.BaseDirectory, "storage");
    public string BaseUrl { get; set; } = "http://172.20.10.5:8080";
}
