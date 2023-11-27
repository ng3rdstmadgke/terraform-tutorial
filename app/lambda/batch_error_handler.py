from api.aws_resource import AwsResource

def handler(event, context):
    print("=== === === batch_error_handler === === ===")
    aws_resource = AwsResource()
    aws_resource.send_message(
        sub="ジョブの実行に失敗しました",
        message="",
        obj=event,
    )

if __name__ == "__main__":
    event = {}
    context = {}
    handler(event, context)