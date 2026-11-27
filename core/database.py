from __future__ import annotations

import os
import json
import shutil
from threading import Lock
from pathlib import Path


class Database:


	def __init__(self, filename):

		self.filename = Path(filename)
	
		self._backup_filename = Path(f"{filename}.bak")
		self._data = {}

		self._serialized_data = None
		self._snapshot = None
		self._lock = Lock()
		self._save_lock = Lock()

		self._load()


	@staticmethod
	def _load_file(filename: Path) -> str:
		try:
			with open(filename, encoding='utf-8') as file:
				return file.read()
		except FileNotFoundError:
			return "{}"
		
	
	@staticmethod
	def _update_file(filename: Path, serialized_data: str):
		# Write to a temporary file first so a crash or error mid-write can't truncate the original
		temp_filename = Path(f"{filename}.tmp")
		with open(temp_filename, 'w', encoding='utf-8') as file:
			file.write(serialized_data)
			file.flush()
			os.fsync(file.fileno())
		try:
			os.replace(temp_filename, filename)
		except PermissionError:
			# On Windows, the replace fails while another process or thread has the file open, so fall back to writing in place
			with open(filename, 'w', encoding='utf-8') as file:
				file.write(serialized_data)
			os.unlink(temp_filename)

	
	@staticmethod
	def _deserialize(serialized_data: str) -> dict:
		return json.loads(serialized_data)


	def _load(self):
		for filename in (self.filename, self._backup_filename):
			try:
				self._load_json(filename)
				return
			except Exception:
				continue
		raise DatabaseException(
			f"Failed to load \"{self.filename}\". "
			f"Loading the backup at \"{self._backup_filename}\" also failed."
		)


	def _load_json(self, filename: Path):
		self._serialized_data = self._load_file(filename)
		self._data = self._deserialize(self._serialized_data)


	def update_json(self):
		# Saves are done one at a time, so an older snapshot can't be written over a newer one
		with self._save_lock:
			# Other threads can change nested entries while they're being serialized, and the indented encoder is pure Python, so
			# it fails with "dictionary changed size during iteration". Snapshot the data with the unindented C encoder first.
			# Only the snapshot is taken while holding the lock, since formatting and writing a large database can take a while,
			# and every other thread using the database would wait for it.
			with self._lock:
				snapshot = json.dumps(self._data)
			if snapshot == self._snapshot:
				return
			serialized_data = json.dumps(json.loads(snapshot), indent=4)
			if serialized_data != self._serialized_data:
				if self.filename.exists():
					if self._backup_filename.exists():
						os.unlink(self._backup_filename)
					shutil.copy(self.filename, self._backup_filename)
				self._update_file(self.filename, serialized_data)
				self._serialized_data = serialized_data
			self._snapshot = snapshot


	def __repr__(self):
		with self._lock:
			return self._data.__repr__()


	def __getitem__(self, key):
		with self._lock:
			return self._data[key]


	def __setitem__(self, key, value):
		with self._lock:
			self._data[key] = value


	def __delitem__(self, key):
		with self._lock:
			del self._data[key]


	def __iter__(self):
		with self._lock:
			return iter(list(self._data.keys()))  # snapshot


	def __len__(self):
		with self._lock:
			return len(self._data)


	def __contains__(self, key):
		with self._lock:
			return key in self._data


	def keys(self):
		with self._lock:
			return list(self._data.keys())


	def values(self):
		with self._lock:
			return list(self._data.values())


	def items(self):
		with self._lock:
			return list(self._data.items())


	def get(self, key, default=None):
		with self._lock:
			return self._data.get(key, default)


	def pop(self, key, default=None):
		with self._lock:
			return self._data.pop(key, default)


	def popitem(self):
		with self._lock:
			return self._data.popitem()


	def clear(self):
		with self._lock:
			self._data.clear()


	def update(self, other=(), **kwargs):
		with self._lock:
			self._data.update(other, **kwargs)


	def setdefault(self, key, default=None):
		with self._lock:
			return self._data.setdefault(key, default)


class DatabaseException(Exception):
	pass
