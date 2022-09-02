# 0 - 14
# 15 - 19
# 20 - 34
# 35 - 39
# 40 - 54
# 55 - 59
# 60 - 74

quantity_array = [
    15, 5, 15, 5, 15, 5, 15
]

entries_array = []

for quantity in quantity_array:
    entries_array.append(entries_array[len(
        entries_array) - 1] + quantity if len(entries_array) > 0 else quantity)


def search(arr, l, r, x):
    if x == 0:
        return 0

    # Check base case
    while r >= l:
        mid = l + (r - l) // 2

        # If the next element is larger than x and
        # the current element is smaller than or equal to x
        if arr[mid] > x and arr[mid - 1] <= x:
            return mid

        # If element is smaller than mid, then it
        # can only be present in left subarray
        elif arr[mid] > x:
            r = mid - 1

        # Else the element can only be present
        # in right subarray
        else:
            l = mid + 1

    # Element is the tail of the array
    return len(arr) - 1


def validate(arr, answer, x):
    if x == 0 and arr[0] >= answer:
        return True

    return arr[x] > answer and arr[x - 1] <= answer


tests = [
    search(entries_array, 0, len(entries_array) - 1, 20) == 2,
    search(entries_array, 0, len(entries_array) - 1, 19) == 1,
    search(entries_array, 0, len(entries_array) - 1, 21) == 2,
    search(entries_array, 0, len(entries_array) - 1, 0) == 0,
    search(entries_array, 0, len(entries_array) - 1, 75) == 6,
    validate(entries_array, 0, 0) == True,
    validate(entries_array, 1, 0) == True,
    validate(entries_array, 14, 0) == True,
    validate(entries_array, 18, 1) == True,
    validate(entries_array, 19, 1) == True,
    validate(entries_array, 20, 2) == True,
    validate(entries_array, 34, 2) == True,
    validate(entries_array, 35, 3) == True,
    validate(entries_array, 39, 3) == True,
    validate(entries_array, 40, 4) == True,
    validate(entries_array, 54, 4) == True,
    validate(entries_array, 55, 5) == True,
    validate(entries_array, 59, 5) == True,
    validate(entries_array, 60, 6) == True,
    validate(entries_array, 74, 6) == True,
    validate(entries_array, 75, 6) == False,
]

print('All tests passing:', all(tests))
