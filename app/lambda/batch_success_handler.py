from api.aws_resource import AwsResource

def handler(event, context):
    print("=== === === batch_success_handler === === ===")
    print("=== === === event === === ===")
    print(event)
    print("=== === === event === === ===")
    print(context)
    aws_resource = AwsResource()
    aws_resource.send_message(
        sub="ジョブの実行に成功しました",
        message="",
        obj=event,
    )


if __name__ == "__main__":
    event = {}
    context = {}
    handler(event, context)