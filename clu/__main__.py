"""Allow running as `python -m clu`."""

from clu.widget import main

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        from clu.widget import _cleanup
        _cleanup()
        print()
