quantity_array = [
    15,5,15,5,15,5,15
]

# 0 - 14
# 15 - 19
# 20 - 34
# 35 - 39
# 40 - 54
# 55 - 59
# 60 - 74

entries_array = []

for quantity in quantity_array:
    entries_array.append(entries_array[len(entries_array) - 1] + quantity if len(entries_array) > 0 else quantity)

def binarySearch(arr, l, r, x):
    # Check base case
    if r >= l:
 
        mid = l + (r - l) // 2
 
        # If element is present at the middle itself
        if arr[mid] == x:
            return mid
 
        # If element is smaller than mid, then it
        # can only be present in left subarray
        elif arr[mid] > x:
            return binarySearch(arr, l, mid-1, x)
 
        # Else the element can only be present
        # in right subarray
        else:
            return binarySearch(arr, mid + 1, r, x)
 
    else:
        # Element is not present in the array
        return -1


# traditional binary search will not work, because if we have ticket 21, then it will fail
# because it will search for 21 in the array, but the array contains 20
# so we need to do a little trick
# we need to find the index of the first element that is greater than the ticket number
# and then we need to subtract 1 from that index
# and then we need to use that index to as the winning ticket number
def fixedBinarySearch(arr, l, r, x):
    if x == 0: return 0

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
    if x == 0 and arr[0] >= answer: return True

    return arr[x] >= answer and arr[x - 1] < answer

print(entries_array)
# this is a normal binary search
print(binarySearch(entries_array, 0, len(entries_array) - 1, 20) == 1)
print(fixedBinarySearch(entries_array, 0, len(entries_array) - 1, 19) == 1)
print(fixedBinarySearch(entries_array, 0, len(entries_array) - 1, 21) == 2)
print(fixedBinarySearch(entries_array, 0, len(entries_array) - 1, 0) == 0)
print(fixedBinarySearch(entries_array, 0, len(entries_array) - 1, 75) == 6)

print('-----------------------------------------------------------')

print(validate(entries_array, 21, 2))
print(validate(entries_array, 0, 0) == True)
print(validate(entries_array, 1, 0) == True)
print(validate(entries_array, 75, 6) == True)

# try:
#     print(validate(entries_array, 76, 6) == False)
# except IndexError:
#     print("Reverted as expected :)")