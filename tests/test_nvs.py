import os
import pty
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

BASH = shutil.which("bash") or "/bin/bash"
NVS = Path(__file__).resolve().parents[1] / ".local/bin/nvs"
HEADER = "| NVIDIA-SMI 535.104.05   Driver Version: 535.104.05   CUDA Version: 12.2 |"
PROCESSES = """| Processes: |
| GPU GI CI PID Type Process name GPU Memory |
| 0 N/A N/A 2060046 C /venv/bin/python 11110MiB |
| 0 N/A N/A 2060099 G /usr/lib/Xorg 256MiB |
| 1 N/A N/A 2060046 C /venv/bin/python 11110MiB |
| 2 N/A N/A 2060047 C+G /opt/my worker 2048MiB |
"""
MOCK = """#!/bin/bash
set -eu
count=0
[[ ! -f $NVS_TEST_COUNT ]] || read -r count < "$NVS_TEST_COUNT"
if [[ $* == --query-gpu=* ]]; then
    if (( count >= ${NVS_TEST_LIMIT:-1000} )); then
        printf 'GPU query unavailable\\n'
        exit 1
    fi
    printf '%s\\n' "$((count + 1))" > "$NVS_TEST_COUNT"
    printf '%s\\n' "$NVS_TEST_GPUS"
else
    if [[ ${NVS_TEST_FAIL_SUMMARY:-0} == 1 ]]; then
        printf 'Process query unavailable\\n'
        exit 1
    fi
    if (( count > 1 )); then
        printf '%s\\n' "${NVS_TEST_NEXT_SUMMARY:-$NVS_TEST_SUMMARY}"
    else
        printf '%s\\n' "$NVS_TEST_SUMMARY"
    fi
fi
"""


class NvsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        mock = self.root / "nvidia-smi"
        mock.write_text(MOCK)
        mock.chmod(0o755)
        (self.root / "bash").symlink_to(BASH)
        self.env = {
            **os.environ,
            "PATH": str(self.root),
            "TERM": "xterm",
            "LC_ALL": "C",
            "NVS_TEST_COUNT": str(self.root / "count"),
            "NVS_TEST_GPUS": "\n".join(
                f"{gpu}, NVIDIA A100-SXM4-80GB, 42, 123.40, 400.00, 11110, 78125, 87" for gpu in range(8)
            ),
            "NVS_TEST_SUMMARY": f"{HEADER}\n{PROCESSES}",
        }

    def run_nvs(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([BASH, str(NVS), *args], env=self.env, text=True, capture_output=True, timeout=5)

    def test_snapshot_has_versions_all_eight_gpus_and_decimal_gb(self) -> None:
        result = self.run_nvs()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines()[:3],
            [
                "8x(A100-SXM)  SMI 535.104.05  Driver 535.104.05  CUDA 12.2",
                "",
                "GPU   C   W/cap    Memory(GB) Util",
            ],
        )
        self.assertNotIn("Every ", result.stdout)
        rows = [line.split() for line in result.stdout.splitlines() if "11.65/81.92" in line]
        self.assertEqual([row[0] for row in rows], [str(gpu) for gpu in range(8)])
        self.assertEqual(rows[0][1:], ["42", "123/400", "11.65/81.92", "87%"])
        self.assertIn("Xorg", result.stdout)
        self.assertIn("my worker", result.stdout)
        self.assertNotIn("\x1b", result.stdout)
        self.assertEqual((self.root / "count").read_text().strip(), "1")

    def test_gpu_and_pid_filters_intersect(self) -> None:
        result = self.run_nvs("-i", "0,2", "-p", "2060046")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1x(A100-SXM)", result.stdout)
        self.assertEqual(result.stdout.count("11.65/81.92"), 1)
        self.assertEqual(result.stdout.count("2060046"), 1)
        self.assertNotIn("2060099", result.stdout)
        self.assertNotIn("2060047", result.stdout)

    def test_multiple_pids_can_select_one_process_on_multiple_gpus(self) -> None:
        result = self.run_nvs("-p", "2060046,2060047")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("3x(A100-SXM)", result.stdout)
        self.assertEqual(result.stdout.count("2060046"), 2)
        self.assertEqual(result.stdout.count("2060047"), 1)
        self.assertNotIn("Xorg", result.stdout)

    def test_missing_pid_keeps_an_empty_snapshot(self) -> None:
        result = self.run_nvs("-p", "999")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("0x(A100-SXM)", result.stdout)
        self.assertIn("No matching GPUs", result.stdout)
        self.assertIn("No matching processes", result.stdout)

    def test_name_mismatch_is_checked_before_pid_filter_and_shortening(self) -> None:
        self.env["NVS_TEST_GPUS"] = self.env["NVS_TEST_GPUS"].replace(
            "1, NVIDIA A100-SXM4-80GB", "1, NVIDIA A100-SXM4-40GB"
        )
        result = self.run_nvs("-p", "2060047")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GPU 1", result.stderr)
        self.assertIn("A100-SXM4-40GB", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_unselected_gpu_names_do_not_cause_a_mismatch(self) -> None:
        self.env["NVS_TEST_GPUS"] = self.env["NVS_TEST_GPUS"].replace("1, NVIDIA A100-SXM4-80GB", "1, NVIDIA H100 PCIe")
        result = self.run_nvs("-i", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1x(H100-PCIe)", result.stdout)

    def test_default_gpu_list_allows_fewer_than_eight_devices(self) -> None:
        self.env["NVS_TEST_GPUS"] = self.env["NVS_TEST_GPUS"].splitlines()[0]
        result = self.run_nvs()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1x(A100-SXM)", result.stdout)

    def test_explicit_missing_gpu_fails(self) -> None:
        result = self.run_nvs("-i", "0,8")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GPU 8 not found", result.stderr)

    def test_non_mig_process_layout_and_unavailable_memory(self) -> None:
        self.env["NVS_TEST_SUMMARY"] = f"{HEADER}\n| 0 2060046 G /usr/lib/Xorg N/A |"
        result = self.run_nvs("-p", "2060046")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1x(A100-SXM)", result.stdout)
        self.assertIn("Xorg", result.stdout)
        self.assertIn("N/A", result.stdout)

    def test_unavailable_gpu_metrics_do_not_become_zero(self) -> None:
        self.env["NVS_TEST_GPUS"] = "0, NVIDIA A100-SXM4-80GB, N/A, [N/A], N/A, N/A, 81920, [N/A]"
        result = self.run_nvs()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("N/A/N/A", result.stdout)
        self.assertIn("N/A/85.90", result.stdout)

    def test_invalid_options_fail_with_a_message(self) -> None:
        for args in [
            ["-n", "0"],
            ["-n", "-1"],
            ["-n", "abc"],
            ["-n", ""],
            ["-i", ""],
            ["-i", "0,"],
            ["-i", "-1"],
            ["-i", "08"],
            ["-p", "0"],
            ["-p", "123x"],
            ["-p", "1,"],
            ["-n"],
            ["-i"],
            ["-t", "0.1"],
            ["-g", "0"],
            ["-x"],
            ["extra"],
        ]:
            with self.subTest(args=args):
                result = self.run_nvs(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("nvs:", result.stderr)

    def test_summary_failure_is_not_reported_as_an_empty_process_list(self) -> None:
        self.env["NVS_TEST_FAIL_SUMMARY"] = "1"
        result = self.run_nvs()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("process query failed", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_help_does_not_need_nvidia_smi(self) -> None:
        (self.root / "nvidia-smi").unlink()
        result = self.run_nvs("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Usage: nvs [-n SECONDS] [-i GPU_IDS] [-p PIDS]", result.stdout)
        result = self.run_nvs()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nvidia-smi not found", result.stderr)

    def test_watch_header_combines_gpu_label_and_versions_without_interval(self) -> None:
        self.env["NVS_TEST_LIMIT"] = "1"
        result = self.run_nvs("-n", "0.1")
        self.assertEqual(
            result.stdout.splitlines()[:3],
            [
                "8x(A100-SXM)  SMI 535.104.05  Driver 535.104.05  CUDA 12.2",
                "",
                "GPU   C   W/cap    Memory(GB) Util",
            ],
        )
        self.assertNotIn("Every ", result.stdout)

    def test_watch_waits_and_propagates_gpu_query_failure_without_external_tools(self) -> None:
        self.env["NVS_TEST_LIMIT"] = "2"
        started = time.monotonic()
        result = self.run_nvs("-n", "0.05")
        elapsed = time.monotonic() - started
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GPU query failed", result.stderr)
        self.assertEqual(result.stdout.count("8x(A100-SXM)"), 2)
        self.assertGreaterEqual(elapsed, 0.1)
        self.assertNotIn("\x1b", result.stdout)

    def test_watch_drops_gpus_when_the_filtered_process_exits(self) -> None:
        self.env["NVS_TEST_LIMIT"] = "2"
        self.env["NVS_TEST_NEXT_SUMMARY"] = f"{HEADER}\n| No running processes found |"
        result = self.run_nvs("-n", "0.01", "-p", "2060046")
        self.assertIn("2x(A100-SXM)", result.stdout)
        self.assertIn("0x(A100-SXM)", result.stdout)
        self.assertIn("No matching GPUs", result.stdout)
        self.assertIn("No matching processes", result.stdout)
        self.assertEqual(result.stdout.count("2060046"), 2)

    def test_watch_restores_terminal_after_failure(self) -> None:
        self.env["NVS_TEST_LIMIT"] = "1"
        master, slave = pty.openpty()
        self.addCleanup(os.close, master)
        self.addCleanup(os.close, slave)
        with subprocess.Popen(
            [BASH, str(NVS), "-n", "0.01"], env=self.env, stdout=slave, stderr=subprocess.PIPE
        ) as process:
            _, stderr = process.communicate(timeout=5)
        self.assertNotEqual(process.returncode, 0)
        self.assertIn(b"GPU query failed", stderr)
        output = os.read(master, 65536)
        self.assertIn(b"\x1b[?1049h\x1b[?25l", output)
        self.assertTrue(output.endswith(b"\x1b[?25h\x1b[?1049l"), output)
