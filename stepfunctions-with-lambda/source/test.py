class TestError(Exception):
    pass


def error_handler(event, context):
    print("called error_handler")


def main_handler(event, context):
    try:
        fail = event['fail']
    except (KeyError, TypeError):
        pass
    else:
        if fail:
            raise TestError("failing as requested")

    return "success"
